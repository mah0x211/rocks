require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local db = require('rockup.db')
local sh = require('rockup.sh')
local registry = require('rockup.registry')

local function tmpdir()
    local d = os.tmpname()
    os.remove(d)
    sh.exec({
        'mkdir',
        '-p',
        d,
    })
    return d
end

local function read_file(path)
    local fh = io.open(path, 'rb')
    if not fh then
        return nil
    end
    local data = fh:read('*a')
    fh:close()
    return data
end

local function seed(conn, repo, filename, name, version, content)
    conn:upsert_rockspec({
        host = 'github.com',
        owner = 'mah0x211',
        repo = repo,
        filename = filename,
        name = name,
        version = version,
        content = content,
    })
end

function testcase.materialize_writes_active_and_removes_orphans()
    local conn = db.open(':memory:')
    seed(conn, 'lua-foo', 'foo-1.0.0-1.rockspec', 'foo', '1.0.0-1', 'FOO-CONTENT')
    seed(conn, 'lua-bar', 'bar-2.0.0-1.rockspec', 'bar', '2.0.0-1', 'BAR-CONTENT')
    -- a soft-deleted rockspec must not be served
    seed(conn, 'lua-baz', 'baz-1.0.0-1.rockspec', 'baz', '1.0.0-1', 'BAZ-CONTENT')
    conn:soft_delete_rockspec({
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-baz',
        filename = 'baz-1.0.0-1.rockspec',
    })

    local dir = tmpdir()
    -- a stale file left from a previous publish
    local orphan = dir .. '/old-9.9.9-1.rockspec'
    local fh = assert(io.open(orphan, 'w'))
    fh:write('stale')
    fh:close()

    local result = registry.materialize(conn, dir)
    assert.equal(#result.written, 2)
    assert.equal(#result.removed, 1)
    assert.equal(result.removed[1], 'old-9.9.9-1.rockspec')

    assert.equal(read_file(dir .. '/foo-1.0.0-1.rockspec'), 'FOO-CONTENT')
    assert.equal(read_file(dir .. '/bar-2.0.0-1.rockspec'), 'BAR-CONTENT')
    assert.is_nil(read_file(dir .. '/baz-1.0.0-1.rockspec'))
    assert.is_nil(read_file(orphan))

    sh.exec({
        'rm',
        '-rf',
        dir,
    })
    conn:close()
end

function testcase.materialize_skips_rows_without_content()
    local conn = db.open(':memory:')
    seed(conn, 'lua-foo', 'foo-1.0.0-1.rockspec', 'foo', '1.0.0-1', nil)

    local dir = tmpdir()
    local result = registry.materialize(conn, dir)
    assert.equal(#result.written, 0)
    assert.is_nil(read_file(dir .. '/foo-1.0.0-1.rockspec'))

    sh.exec({
        'rm',
        '-rf',
        dir,
    })
    conn:close()
end

function testcase.regenerate_manifest_produces_manifests_and_zips()
    local dir = tmpdir()
    local spec = table.concat({
        'package = "foo"',
        'version = "1.0.0-1"',
        'source = { url = "git+https://github.com/mah0x211/lua-foo.git", tag = "v1.0.0" }',
        'description = { summary = "x", license = "MIT" }',
        'build = { type = "builtin", modules = { foo = "foo.lua" } }',
    }, '\n')
    local fh = assert(io.open(dir .. '/foo-1.0.0-1.rockspec', 'w'))
    fh:write(spec)
    fh:close()

    registry.regenerate_manifest(dir)

    assert.not_nil(read_file(dir .. '/manifest'))
    assert.not_nil(read_file(dir .. '/manifest-5.1'))
    assert.not_nil(read_file(dir .. '/manifest-5.1.zip'))
    assert.match(read_file(dir .. '/manifest'), 'foo')

    sh.exec({
        'rm',
        '-rf',
        dir,
    })
end

function testcase.regenerate_manifest_zips_are_deterministic()
    local dir = tmpdir()
    local spec = table.concat({
        'package = "foo"',
        'version = "1.0.0-1"',
        'source = { url = "git+https://github.com/mah0x211/lua-foo.git", tag = "v1.0.0" }',
        'description = { summary = "x", license = "MIT" }',
        'build = { type = "builtin", modules = { foo = "foo.lua" } }',
    }, '\n')
    local fh = assert(io.open(dir .. '/foo-1.0.0-1.rockspec', 'w'))
    fh:write(spec)
    fh:close()

    registry.regenerate_manifest(dir)
    local first = read_file(dir .. '/manifest-5.1.zip')
    registry.regenerate_manifest(dir)
    local second = read_file(dir .. '/manifest-5.1.zip')
    assert.equal(first, second)

    sh.exec({
        'rm',
        '-rf',
        dir,
    })
end

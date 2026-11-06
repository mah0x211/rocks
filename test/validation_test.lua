require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local validation = require('rockup.validation')

local VALID = table.concat({
    'package = "foo"',
    'version = "1.0.0-1"',
    'source = {',
    '    url = "git+https://github.com/mah0x211/lua-foo.git",',
    '    tag = "v1.0.0",',
    '}',
    'description = {',
    '    summary = "a test package",',
    '    license = "MIT",',
    '}',
    'dependencies = {',
    '    "lua >= 5.1",',
    '}',
    'build = {',
    '    type = "builtin",',
    '    modules = {',
    '        foo = "foo.lua",',
    '    },',
    '}',
}, '\n')

local function rec(content, overrides)
    local r = {
        filename = 'foo-1.0.0-1.rockspec',
        name = 'foo',
        version = '1.0.0-1',
        content = content or VALID,
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
    }
    for k, v in pairs(overrides or {}) do
        r[k] = v
    end
    return r
end

local function pass_lint()
    return true
end

local function github_tag(result)
    return {
        list_tags = function(_, _, _)
            if result then
                return {
                    ['v1.0.0'] = true,
                }
            end
            return {}
        end,
    }
end

function testcase.accepts_valid_rockspec_with_existing_tag()
    local validate = validation.new({
        github = github_tag(true),
        lint = pass_lint,
    })
    local ok, err, meta = validate(rec())
    assert.equal(ok, true)
    assert.is_nil(err)
    assert.equal(meta.source_url, 'git+https://github.com/mah0x211/lua-foo.git')
    assert.equal(meta.source_host, 'github.com')
    assert.equal(meta.source_owner, 'mah0x211')
    assert.equal(meta.source_repo, 'lua-foo')
end

function testcase.rejects_when_tag_is_missing()
    local validate = validation.new({
        github = github_tag(false),
        lint = pass_lint,
    })
    local ok, err = validate(rec())
    assert.equal(ok, false)
    assert.match(err, 'source.tag v1.0.0 not found')
end

function testcase.rejects_package_name_mismatch()
    local content = VALID:gsub('package = "foo"', 'package = "bar"')
    local validate = validation.new({
        github = github_tag(true),
        lint = pass_lint,
    })
    local ok, err = validate(rec(content))
    assert.equal(ok, false)
    assert.match(err, 'does not match filename name')
end

function testcase.rejects_version_mismatch()
    local content = VALID:gsub('version = "1.0.0%-1"', 'version = "2.0.0-1"')
    local validate = validation.new({
        github = github_tag(true),
        lint = pass_lint,
    })
    local ok, err = validate(rec(content))
    assert.equal(ok, false)
    assert.match(err, 'does not match filename version')
end

function testcase.rejects_unreadable_content()
    local validate = validation.new({
        github = github_tag(true),
        lint = pass_lint,
    })
    local ok, err = validate(rec('this is not = valid lua'))
    assert.equal(ok, false)
    assert.match(err, 'could not read rockspec')
end

function testcase.rejects_lint_failure()
    local validate = validation.new({
        github = github_tag(true),
        lint = function()
            return false, 'bad rockspec'
        end,
    })
    local ok, err = validate(rec())
    assert.equal(ok, false)
    assert.match(err, 'luarocks lint failed')
end

function testcase.accepts_scm_rockspec_without_tag()
    local content = table.concat({
        'package = "foo"',
        'version = "scm-1"',
        'source = { url = "git+https://github.com/mah0x211/lua-foo.git" }',
        'build = { type = "builtin", modules = {} }',
    }, '\n')
    local validate = validation.new({
        github = {
            list_tags = function()
                error('list_tags must not be called without a tag')
            end,
        },
        lint = pass_lint,
    })
    local ok = validate(rec(content, {
        filename = 'foo-scm-1.rockspec',
        version = 'scm-1',
    }))
    assert.equal(ok, true)
end

function testcase.caches_tag_set_per_repository()
    local calls = 0
    local validate = validation.new({
        github = {
            list_tags = function()
                calls = calls + 1
                return {
                    ['v1.0.0'] = true,
                }
            end,
        },
        lint = pass_lint,
    })
    assert.equal(validate(rec()), true)
    assert.equal(validate(rec()), true)
    assert.equal(calls, 1)
end

function testcase.rejects_tag_on_non_github_source()
    local content = table.concat({
        'package = "foo"',
        'version = "1.0.0-1"',
        'source = { url = "https://example.com/foo-1.0.0.tar.gz", tag = "v1.0.0" }',
        'build = { type = "builtin", modules = {} }',
    }, '\n')
    local validate = validation.new({
        github = github_tag(true),
        lint = pass_lint,
    })
    local ok, err = validate(rec(content))
    assert.equal(ok, false)
    assert.match(err, 'cannot verify source.tag')
end

function testcase.default_lint_accepts_a_valid_rockspec()
    assert.equal(validation.default_lint('foo-1.0.0-1.rockspec', VALID), true)
end

function testcase.default_lint_rejects_broken_content()
    local ok, err = validation.default_lint('x-1.0-1.rockspec', 'this is = not lua')
    assert.equal(ok, false)
    assert.not_nil(err)
end

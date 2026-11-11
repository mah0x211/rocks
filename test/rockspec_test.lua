require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local rockspec = require('rockup.rockspec')

function testcase.basename_returns_last_segment()
    assert.equal(rockspec.basename('rockspecs/foo-1.0.0-1.rockspec'), 'foo-1.0.0-1.rockspec')
    assert.equal(rockspec.basename('foo-1.0.0-1.rockspec'), 'foo-1.0.0-1.rockspec')
    assert.equal(rockspec.basename('a/b/c.txt'), 'c.txt')
end

function testcase.parse_filename_splits_name_and_version()
    local name, version = rockspec.parse_filename('net-http-0.1.6-1.rockspec')
    assert.equal(name, 'net-http')
    assert.equal(version, '0.1.6-1')

    name, version = rockspec.parse_filename('form-urlencoded-dev-1.rockspec')
    assert.equal(name, 'form-urlencoded')
    assert.equal(version, 'dev-1')
end

function testcase.parse_filename_rejects_non_rockspec()
    assert.is_nil(rockspec.parse_filename('README.md'))
    assert.is_nil(rockspec.parse_filename('foo.rockspec'))
end

function testcase.load_extracts_assigned_fields()
    local spec = rockspec.load('package = "foo"\nversion = "1.0.0-1"\n' ..
        'source = { url = "git+https://github.com/mah0x211/lua-foo.git", tag = "v1" }')
    assert.equal(spec.package, 'foo')
    assert.equal(spec.version, '1.0.0-1')
    assert.equal(spec.source.url, 'git+https://github.com/mah0x211/lua-foo.git')
    assert.equal(spec.source.tag, 'v1')
end

function testcase.load_returns_error_for_invalid_lua()
    local spec, err = rockspec.load('this is = not lua')
    assert.is_nil(spec)
    assert.not_nil(err)
end

function testcase.load_sandbox_blocks_library_access()
    -- os is not exposed in the sandbox, so calling it raises and the rockspec is
    -- reported as unloadable rather than executing.
    local spec, err = rockspec.load('os.execute("echo pwned")')
    assert.is_nil(spec)
    assert.not_nil(err)
end

function testcase.parse_source_url_extracts_github_coordinates()
    local host, owner, repo = rockspec.parse_source_url(
        'git+https://github.com/mah0x211/lua-foo.git')
    assert.equal(host, 'github.com')
    assert.equal(owner, 'mah0x211')
    assert.equal(repo, 'lua-foo')

    host, owner, repo = rockspec.parse_source_url('https://github.com/owner/repo')
    assert.equal(host, 'github.com')
    assert.equal(owner, 'owner')
    assert.equal(repo, 'repo')
end

function testcase.parse_source_url_returns_nil_for_non_github()
    assert.is_nil(rockspec.parse_source_url('https://example.com/foo.tar.gz'))
    assert.is_nil(rockspec.parse_source_url(nil))
end

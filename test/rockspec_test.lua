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

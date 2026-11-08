require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local sh = require('rockup.sh')

local DB = '/tmp/rockup_cli_test.db'

local function rockup(...)
    local argv = {
        'env',
        '-u',
        'GITHUB_STEP_SUMMARY',
        'lua',
        '../bin/rockup.lua',
    }
    for _, a in ipairs({
        ...,
    }) do
        argv[#argv + 1] = a
    end
    return sh.exec(argv)
end

local function cleanup()
    sh.exec({
        'rm',
        '-f',
        DB,
    })
end

function testcase.exclude_without_a_target_fails()
    local code, out = rockup('exclude', '--db', DB, '--serve-dir', '/tmp/x')
    assert.not_equal(code, 0)
    assert.match(out, 'requires at least one')
    cleanup()
end

function testcase.scan_rejects_multiple_targets()
    local code, out = rockup('scan', 'a/b', 'c/d', '--db', DB, '--serve-dir', '/tmp/x')
    assert.not_equal(code, 0)
    assert.match(out, 'single owner/repo')
    cleanup()
end

function testcase.sync_requires_serve_dir()
    local code, out = rockup('sync', '--db', DB)
    assert.not_equal(code, 0)
    assert.match(out, 'serve%-dir', false)
    cleanup()
end

function testcase.option_without_value_fails()
    local code, out = rockup('state', '--db')
    assert.not_equal(code, 0)
    assert.match(out, '%-%-db requires a value', false)
    cleanup()
end

function testcase.unknown_command_fails()
    local code, out = rockup('bogus', '--db', DB)
    assert.not_equal(code, 0)
    assert.match(out, 'unknown command')
    cleanup()
end

function testcase.state_on_a_fresh_database_succeeds()
    cleanup()
    local code, out = rockup('state', '--db', DB)
    assert.equal(code, 0)
    assert.match(out, 'registry state')
    cleanup()
end

require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local gh = require('rockup.gh')

function testcase.shquote_escapes_single_quotes()
    assert.equal(gh.shquote("a'b"), "'a'\\''b'")
    assert.equal(gh.shquote('plain'), "'plain'")
end

function testcase.exec_captures_output_and_zero_exit()
    local code, out = gh.exec({
        'printf',
        'hello',
    })
    assert.equal(code, 0)
    assert.equal(out, 'hello')
end

function testcase.exec_captures_nonzero_exit_and_stderr()
    local code, out = gh.exec({
        'sh',
        '-c',
        'echo oops >&2; exit 5',
    })
    assert.equal(code, 5)
    assert.match(out, 'oops')
end

function testcase.exec_quotes_arguments_safely()
    local code, out = gh.exec({
        'printf',
        '%s',
        "a b'c",
    })
    assert.equal(code, 0)
    assert.equal(out, "a b'c")
end

function testcase.api_builds_expected_argv()
    local captured
    local code, out = gh.api('repos/x/y/git/trees/main', {
        paginate = true,
        silent = true,
        headers = {
            'Accept: application/vnd.github.raw',
        },
        jq = '.tree',
    }, function(argv)
        captured = argv
        return 0, 'ok'
    end)
    assert.equal(code, 0)
    assert.equal(out, 'ok')
    assert.equal(captured[1], 'gh')
    assert.equal(captured[2], 'api')
    assert.equal(captured[3], 'repos/x/y/git/trees/main')

    local joined = table.concat(captured, ' ')
    assert.match(joined, '--paginate')
    assert.match(joined, '--silent')
    assert.match(joined, '-H Accept: application/vnd.github.raw')
    assert.match(joined, '--jq .tree')
end

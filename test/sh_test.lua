require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local sh = require('rockup.sh')

function testcase.shquote_escapes_single_quotes()
    assert.equal(sh.shquote("a'b"), "'a'\\''b'")
    assert.equal(sh.shquote('plain'), "'plain'")
end

function testcase.exec_captures_output_and_zero_exit()
    local code, out = sh.exec({
        'printf',
        'hello',
    })
    assert.equal(code, 0)
    assert.equal(out, 'hello')
end

function testcase.exec_captures_nonzero_exit_and_stderr()
    local code, out = sh.exec({
        'sh',
        '-c',
        'echo oops >&2; exit 5',
    })
    assert.equal(code, 5)
    assert.match(out, 'oops')
end

function testcase.exec_quotes_arguments_safely()
    local code, out = sh.exec({
        'printf',
        '%s',
        "a b'c",
    })
    assert.equal(code, 0)
    assert.equal(out, "a b'c")
end

function testcase.read_returns_raw_stdout_preserving_trailing_newline()
    assert.equal(sh.read({
        'printf',
        'a\nb\n',
    }), 'a\nb\n')
end

function testcase.read_discards_stderr()
    assert.equal(sh.read({
        'sh',
        '-c',
        'printf out; printf err >&2',
    }), 'out')
end

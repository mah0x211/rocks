require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local gh = require('rockup.gh')

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

function testcase.api_omits_absent_options()
    local captured
    gh.api('rate_limit', nil, function(argv)
        captured = argv
        return 0, '{}'
    end)
    assert.equal(#captured, 3)
    assert.equal(captured[3], 'rate_limit')
end

require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local github = require('rockup.github')

--- Builds an `api` stub that dispatches on a path substring.
local function stub(routes)
    return function(path, opts)
        for _, route in ipairs(routes) do
            if path:find(route.match, 1, true) then
                route.opts = opts
                return route.code or 0, route.out or ''
            end
        end
        error('no stub for ' .. path)
    end
end

function testcase.list_repos_maps_fields()
    local gh = github.new({
        api = stub({
            {
                match = 'users/mah0x211/repos',
                out = 'lua-foo\tmaster\t2026-01-02T00:00:00Z\tfalse\n' ..
                    'lua-bar\tmain\t2026-01-01T00:00:00Z\ttrue',
            },
        }),
    })
    local repos = gh:list_repos('mah0x211')
    assert.equal(#repos, 2)
    assert.equal(repos[1].name, 'lua-foo')
    assert.equal(repos[1].default_branch, 'master')
    assert.equal(repos[1].pushed_at, '2026-01-02T00:00:00Z')
    assert.equal(repos[1].fork, false)
    assert.equal(repos[2].fork, true)
end

function testcase.list_repos_handles_empty_default_branch()
    local gh = github.new({
        api = stub({
            {
                match = 'repos',
                out = 'lua-foo\t\t2026-01-02T00:00:00Z\tfalse',
            },
        }),
    })
    local repos = gh:list_repos('mah0x211')
    assert.is_nil(repos[1].default_branch)
end

function testcase.list_repos_raises_on_failure()
    local gh = github.new({
        api = stub({
            {
                match = 'repos',
                code = 1,
                out = 'gh: Internal Error (HTTP 500)',
            },
        }),
    })
    local err = assert.throws(function()
        gh:list_repos('mah0x211')
    end)
    assert.match(err, 'HTTP 500')
end

function testcase.list_rockspecs_filters_and_strips_truncated_marker()
    local gh = github.new({
        api = stub({
            {
                match = 'git/trees',
                out = 'truncated:false\n' ..
                    'rockspecs/foo-1.0.0-1.rockspec\ts1\n' ..
                    'foo-2.0.0-1.rockspec\ts2',
            },
        }),
    })
    local specs = gh:list_rockspecs('mah0x211', 'lua-foo', 'master')
    assert.equal(#specs, 2)
    assert.equal(specs[1].path, 'rockspecs/foo-1.0.0-1.rockspec')
    assert.equal(specs[1].sha, 's1')
    assert.equal(specs[2].sha, 's2')
end

function testcase.list_rockspecs_errors_on_truncated_tree()
    local gh = github.new({
        api = stub({
            {
                match = 'git/trees',
                out = 'truncated:true',
            },
        }),
    })
    local err = assert.throws(function()
        gh:list_rockspecs('mah0x211', 'lua-foo', 'master')
    end)
    assert.match(err, 'truncated')
end

function testcase.list_rockspecs_returns_empty_for_missing_ref()
    local gh = github.new({
        api = stub({
            {
                match = 'git/trees',
                code = 1,
                out = 'gh: Not Found (HTTP 404)',
            },
        }),
    })
    assert.equal(#gh:list_rockspecs('mah0x211', 'lua-foo', 'master'), 0)
end

function testcase.list_rockspecs_raises_on_other_errors()
    local gh = github.new({
        api = stub({
            {
                match = 'git/trees',
                code = 1,
                out = 'gh: rate limited (HTTP 403)',
            },
        }),
    })
    assert.throws(function()
        gh:list_rockspecs('mah0x211', 'lua-foo', 'master')
    end)
end

function testcase.fetch_blobs_delegates_to_git_client()
    local seen = {}
    local gh = github.new({
        git = {
            fetch_blobs = function(_, host, owner, repo, shas)
                seen = {
                    host = host,
                    owner = owner,
                    repo = repo,
                    shas = shas,
                }
                return {
                    [shas[1]] = 'content-' .. shas[1],
                }
            end,
        },
    })
    local out = gh:fetch_blobs('mah0x211', 'lua-foo', {
        'abc',
    })
    assert.equal(out.abc, 'content-abc')
    assert.equal(seen.host, 'github.com')
    assert.equal(seen.owner, 'mah0x211')
    assert.equal(seen.repo, 'lua-foo')
end

function testcase.list_tags_delegates_to_git_client()
    local gh = github.new({
        git = {
            list_tags = function(_, host, owner, repo)
                assert.equal(host, 'github.com')
                assert.equal(owner, 'mah0x211')
                assert.equal(repo, 'lua-foo')
                return {
                    ['v1.0.0'] = true,
                }
            end,
        },
    })
    local tags = gh:list_tags('mah0x211', 'lua-foo')
    assert.equal(tags['v1.0.0'], true)
    assert.is_nil(tags['v9.9.9'])
end

function testcase.default_branch_returns_the_branch()
    local gh = github.new({
        api = function()
            return 0, 'main\n'
        end,
    })
    assert.equal(gh:default_branch('mah0x211', 'lua-foo'), 'main')
end

function testcase.default_branch_raises_on_failure()
    local gh = github.new({
        api = function()
            return 1, 'gh: Not Found (HTTP 404)'
        end,
    })
    assert.throws(function()
        gh:default_branch('mah0x211', 'lua-foo')
    end)
end

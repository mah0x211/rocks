require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local gitrepo = require('rockup.gitrepo')

local function join(argv)
    return table.concat(argv, ' ')
end

function testcase.fetch_blobs_fetches_then_reads_each_blob()
    local contents = {
        aaa = 'rock-A\n',
        bbb = 'rock-B',
    }
    local fetched
    local removed
    local git = gitrepo.new({
        exec = function(argv)
            if argv[1] == 'mktemp' then
                return 0, '/tmp/wd\n'
            elseif argv[1] == 'rm' then
                removed = argv[3]
                return 0, ''
            elseif argv[1] == 'git' then
                local sub = argv[4]
                if sub == 'init' then
                    return 0, ''
                elseif sub == 'fetch' then
                    fetched = argv
                    return 0, ''
                elseif sub == 'cat-file' then
                    return 0, tostring(#contents[argv[6]])
                end
            end
            error('unexpected exec: ' .. join(argv))
        end,
        read = function(argv)
            return contents[argv[6]]
        end,
    })

    local out = git:fetch_blobs('github.com', 'mah0x211', 'lua-foo', {
        'aaa',
        'bbb',
    })
    assert.equal(out.aaa, 'rock-A\n')
    assert.equal(out.bbb, 'rock-B')
    -- a single fetch carries the clone URL and every requested blob SHA
    assert.equal(fetched[7], 'https://github.com/mah0x211/lua-foo.git')
    assert.equal(fetched[8], 'aaa')
    assert.equal(fetched[9], 'bbb')
    -- the temporary working directory is removed afterwards
    assert.equal(removed, '/tmp/wd')
end

function testcase.fetch_blobs_returns_empty_without_shas()
    local git = gitrepo.new({
        exec = function()
            error('exec must not run')
        end,
        read = function()
            error('read must not run')
        end,
    })
    assert.equal(next(git:fetch_blobs('github.com', 'o', 'r', {})), nil)
end

function testcase.fetch_blobs_rejects_size_mismatch()
    local git = gitrepo.new({
        exec = function(argv)
            if argv[1] == 'mktemp' then
                return 0, '/tmp/wd'
            elseif argv[1] == 'rm' then
                return 0, ''
            elseif argv[4] == 'cat-file' then
                return 0, '999'
            end
            return 0, ''
        end,
        read = function()
            return 'short'
        end,
    })
    local err = assert.throws(function()
        git:fetch_blobs('github.com', 'o', 'r', {
            'aaa',
        })
    end)
    assert.match(err, 'size mismatch')
end

function testcase.fetch_blobs_cleans_up_on_fetch_failure()
    local removed
    local git = gitrepo.new({
        exec = function(argv)
            if argv[1] == 'mktemp' then
                return 0, '/tmp/wd'
            elseif argv[1] == 'rm' then
                removed = true
                return 0, ''
            elseif argv[4] == 'fetch' then
                return 128, 'fatal: boom'
            end
            return 0, ''
        end,
        read = function()
            return ''
        end,
    })
    local err = assert.throws(function()
        git:fetch_blobs('github.com', 'o', 'r', {
            'aaa',
        })
    end)
    assert.match(err, 'git fetch')
    assert.equal(removed, true)
end

function testcase.list_tags_parses_names_and_folds_peeled_refs()
    local git = gitrepo.new({
        exec = function(argv)
            assert.equal(argv[2], 'ls-remote')
            assert.equal(argv[3], '--tags')
            return 0, table.concat({
                'sha1\trefs/tags/v1.0.0',
                'sha2\trefs/tags/v1.0.0^{}',
                'sha3\trefs/tags/v2.0.0',
                'sha4\trefs/heads/master',
            }, '\n')
        end,
    })
    local tags = git:list_tags('github.com', 'mah0x211', 'lua-foo')
    assert.equal(tags['v1.0.0'], true)
    assert.equal(tags['v2.0.0'], true)
    assert.is_nil(tags['master'])
end

function testcase.list_tags_raises_on_failure()
    local git = gitrepo.new({
        exec = function()
            return 128, 'fatal: repository not found'
        end,
    })
    assert.throws(function()
        git:list_tags('github.com', 'o', 'r')
    end)
end

require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local db = require('rockup.db')
local sh = require('rockup.sh')
local sync = require('rockup.sync')

local HOST = 'github.com'

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

local function fake_gh(cfg)
    return {
        list_repos = function(_, owner)
            return (cfg.repos_by_owner and cfg.repos_by_owner[owner]) or {}
        end,
        list_rockspecs = function(_, _, repo, _)
            return (cfg.trees and cfg.trees[repo]) or {}
        end,
        fetch_blobs = function(_, _, _, shas)
            local out = {}
            for _, sha in ipairs(shas) do
                out[sha] = 'content-' .. sha
            end
            return out
        end,
        list_tags = function()
            return setmetatable({}, {
                __index = function()
                    return true
                end,
            })
        end,
    }
end

function testcase.run_all_crawls_every_enabled_source()
    local conn = db.open(':memory:')
    conn:upsert_source({
        host = HOST,
        owner = 'mah0x211',
    })
    conn:upsert_source({
        host = HOST,
        owner = 'other',
        enabled = false,
    })
    local gh = fake_gh({
        repos_by_owner = {
            mah0x211 = {
                {
                    name = 'lua-foo',
                    default_branch = 'master',
                    pushed_at = '2026-01-01T00:00:00Z',
                    fork = false,
                },
            },
        },
        trees = {
            ['lua-foo'] = {
                {
                    path = 'foo-1.0.0-1.rockspec',
                    sha = 's1',
                },
            },
        },
    })

    local aggregate = sync.run_all(conn, gh, {
        now_epoch = 1800000000,
    })
    assert.equal(#aggregate.sources, 1)
    assert.equal(aggregate.changed, true)
    assert.equal(conn:count_active_rockspecs(), 1)
    conn:close()
end

function testcase.run_all_skips_sources_not_due()
    local conn = db.open(':memory:')
    conn:upsert_source({
        host = HOST,
        owner = 'mah0x211',
    })
    conn:update_source_crawl_state({
        host = HOST,
        owner = 'mah0x211',
        next_crawl_due = '2099-01-01T00:00:00Z',
        backoff_step = 1,
    })
    local gh = fake_gh({})

    local aggregate = sync.run_all(conn, gh, {
        now_iso = '2026-01-01T00:00:00Z',
    })
    assert.equal(aggregate.sources[1].result.skipped, true)
    assert.equal(aggregate.changed, false)
    conn:close()
end

function testcase.publish_materializes_and_builds_manifest()
    local conn = db.open(':memory:')
    conn:upsert_rockspec({
        host = HOST,
        owner = 'mah0x211',
        repo = 'lua-foo',
        filename = 'foo-1.0.0-1.rockspec',
        name = 'foo',
        version = '1.0.0-1',
        content = table.concat({
            'package = "foo"',
            'version = "1.0.0-1"',
            'source = { url = "git+https://github.com/mah0x211/lua-foo.git", tag = "v1" }',
            'build = { type = "builtin", modules = { foo = "foo.lua" } }',
        }, '\n'),
    })
    local dir = tmpdir()
    sync.publish(conn, dir)

    local fh = io.open(dir .. '/manifest', 'r')
    assert.not_nil(fh)
    fh:close()
    local rfh = io.open(dir .. '/foo-1.0.0-1.rockspec', 'r')
    assert.not_nil(rfh)
    rfh:close()

    sh.exec({
        'rm',
        '-rf',
        dir,
    })
    conn:close()
end

function testcase.run_all_isolates_a_failing_source()
    local conn = db.open(':memory:')
    conn:upsert_source({
        host = HOST,
        owner = 'bad',
    })
    conn:upsert_source({
        host = HOST,
        owner = 'good',
    })
    local gh = {
        list_repos = function(_, owner)
            if owner == 'bad' then
                error('boom')
            end
            return {
                {
                    name = 'lua-foo',
                    default_branch = 'master',
                    pushed_at = '2026-01-01T00:00:00Z',
                    fork = false,
                },
            }
        end,
        list_rockspecs = function()
            return {
                {
                    path = 'foo-1.0.0-1.rockspec',
                    sha = 's1',
                },
            }
        end,
        fetch_blobs = function(_, _, _, shas)
            local out = {}
            for _, sha in ipairs(shas) do
                out[sha] = 'content-' .. sha
            end
            return out
        end,
        list_tags = function()
            return setmetatable({}, {
                __index = function()
                    return true
                end,
            })
        end,
    }

    local aggregate = sync.run_all(conn, gh, {
        now_epoch = 1800000000,
    })
    assert.equal(#aggregate.sources, 2)
    assert.equal(aggregate.changed, true)
    assert.equal(conn:count_active_rockspecs(), 1)

    local failures = 0
    for _, s in ipairs(aggregate.sources) do
        if s.result.error then
            failures = failures + 1
        end
    end
    assert.equal(failures, 1)
    conn:close()
end

function testcase.seed_existing_imports_as_grandfathered_with_provenance()
    local conn = db.open(':memory:')
    local dir = tmpdir()
    local fh = assert(io.open(dir .. '/foo-1.0.0-1.rockspec', 'w'))
    fh:write(table.concat({
        'package = "foo"',
        'version = "1.0.0-1"',
        'source = { url = "git+https://github.com/mah0x211/lua-foo.git", tag = "v1" }',
    }, '\n'))
    fh:close()

    local imported = sync.seed_existing(conn, dir)
    assert.equal(imported, 1)

    local row = conn:get_rockspec(HOST, 'mah0x211', 'lua-foo', 'foo-1.0.0-1.rockspec')
    assert.equal(row.managed, 0)
    assert.equal(row.source_owner, 'mah0x211')

    -- a later crawl of the real repository takes the row over without a collision
    conn:upsert_rockspec({
        host = HOST,
        owner = 'mah0x211',
        repo = 'lua-foo',
        filename = 'foo-1.0.0-1.rockspec',
        name = 'foo',
        version = '1.0.0-1',
        blob_sha = 's1',
        content = 'updated',
    })
    local taken = conn:get_rockspec(HOST, 'mah0x211', 'lua-foo', 'foo-1.0.0-1.rockspec')
    assert.equal(taken.managed, 1)

    sh.exec({
        'rm',
        '-rf',
        dir,
    })
    conn:close()
end

require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local db = require('rockup.db')
local control = require('rockup.control')

local HOST = 'github.com'
local OWNER = 'mah0x211'

local function fake_gh(cfg)
    return {
        list_repos = function()
            return cfg.repos or {}
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
        default_branch = function()
            return 'master'
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

local function seed_spec(conn, repo, name, version)
    conn:upsert_rockspec({
        host = HOST,
        owner = OWNER,
        repo = repo,
        filename = string.format('%s-%s.rockspec', name, version),
        name = name,
        version = version,
        blob_sha = 's',
    })
end

function testcase.parse_target_handles_owner_repo_and_host_forms()
    local t = control.parse_target('mah0x211/lua-foo')
    assert.equal(t.host, 'github.com')
    assert.equal(t.owner, 'mah0x211')
    assert.equal(t.repo, 'lua-foo')

    local t3 = control.parse_target('example.com/owner/repo')
    assert.equal(t3.host, 'example.com')
    assert.equal(t3.owner, 'owner')
    assert.equal(t3.repo, 'repo')

    assert.is_nil(control.parse_target('just-one-part'))
end

function testcase.pause_and_resume_toggle_meta()
    local conn = db.open(':memory:')
    control.pause(conn)
    assert.equal(conn:is_paused(), true)
    control.resume(conn)
    assert.equal(conn:is_paused(), false)
    conn:close()
end

function testcase.set_ignore_true_soft_deletes_rockspecs()
    local conn = db.open(':memory:')
    seed_spec(conn, 'lua-foo', 'foo', '1.0.0-1')
    seed_spec(conn, 'lua-foo', 'foo', '1.1.0-1')
    assert.equal(conn:count_active_rockspecs(), 2)

    local report = control.set_ignore(conn, nil, {
        {
            host = HOST,
            owner = OWNER,
            repo = 'lua-foo',
        },
    }, true)
    assert.equal(#report.ignored, 1)
    assert.equal(#report.deleted, 2)
    assert.equal(conn:count_active_rockspecs(), 0)
    assert.equal(conn:get_repo(HOST, OWNER, 'lua-foo').ignore, 1)
    conn:close()
end

function testcase.set_ignore_false_rescans_and_reincludes()
    local conn = db.open(':memory:')
    conn:upsert_repo({
        host = HOST,
        owner = OWNER,
        repo = 'lua-foo',
    })
    conn:set_repo_ignore({
        host = HOST,
        owner = OWNER,
        repo = 'lua-foo',
        ignore = true,
    })
    local gh = fake_gh({
        trees = {
            ['lua-foo'] = {
                {
                    path = 'foo-1.0.0-1.rockspec',
                    sha = 's1',
                },
            },
        },
    })

    local report = control.set_ignore(conn, gh, {
        {
            host = HOST,
            owner = OWNER,
            repo = 'lua-foo',
        },
    }, false)
    assert.equal(#report.unignored, 1)
    assert.equal(#report.added, 1)
    assert.equal(conn:get_repo(HOST, OWNER, 'lua-foo').ignore, 0)
    assert.equal(conn:count_active_rockspecs(), 1)
    conn:close()
end

function testcase.scan_once_records_without_adding_a_source()
    local conn = db.open(':memory:')
    local gh = fake_gh({
        trees = {
            ['lua-foo'] = {
                {
                    path = 'foo-1.0.0-1.rockspec',
                    sha = 's1',
                },
            },
        },
    })
    local report = control.scan_once(conn, gh, {
        host = HOST,
        owner = OWNER,
        repo = 'lua-foo',
    })
    assert.equal(#report.added, 1)
    assert.equal(conn:count_active_rockspecs(), 1)
    assert.equal(#conn:list_sources(), 0)
    conn:close()
end

function testcase.re_include_revives_grandfathered_versions()
    local conn = db.open(':memory:')
    -- an old grandfathered version plus a managed current version
    conn:upsert_rockspec({
        host = HOST,
        owner = OWNER,
        repo = 'lua-foo',
        filename = 'foo-0.1.0-1.rockspec',
        name = 'foo',
        version = '0.1.0-1',
        content = 'old',
        managed = false,
    })
    conn:upsert_rockspec({
        host = HOST,
        owner = OWNER,
        repo = 'lua-foo',
        filename = 'foo-0.2.0-1.rockspec',
        name = 'foo',
        version = '0.2.0-1',
        blob_sha = 's2',
        content = 'cur',
    })

    -- exclude removes both from serving
    control.set_ignore(conn, nil, {
        {
            host = HOST,
            owner = OWNER,
            repo = 'lua-foo',
        },
    }, true)
    assert.equal(conn:count_active_rockspecs(), 0)

    -- re-include: the current version is re-crawled and the grandfathered old
    -- version is revived even though it is not in the tree.
    local gh = fake_gh({
        trees = {
            ['lua-foo'] = {
                {
                    path = 'foo-0.2.0-1.rockspec',
                    sha = 's2',
                },
            },
        },
    })
    control.set_ignore(conn, gh, {
        {
            host = HOST,
            owner = OWNER,
            repo = 'lua-foo',
        },
    }, false)

    assert.is_nil(conn:get_rockspec(HOST, OWNER, 'lua-foo', 'foo-0.1.0-1.rockspec').deleted_at)
    assert.is_nil(conn:get_rockspec(HOST, OWNER, 'lua-foo', 'foo-0.2.0-1.rockspec').deleted_at)
    assert.equal(conn:count_active_rockspecs(), 2)
    conn:close()
end

function testcase.source_management_adds_and_toggles()
    local conn = db.open(':memory:')
    control.add_source(conn, {
        host = HOST,
        owner = OWNER,
    })
    assert.equal(#conn:list_sources(), 1)
    assert.equal(#conn:list_enabled_sources(), 1)

    control.set_source_enabled(conn, HOST, OWNER, false)
    assert.equal(#conn:list_enabled_sources(), 0)
    assert.equal(#conn:list_sources(), 1)
    conn:close()
end

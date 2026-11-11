require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local db = require('rockup.db')
local schedule = require('rockup.schedule')

local HOUR = 3600

local function fake_gh(cfg)
    return {
        list_repos = function(_, _)
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
        list_tags = function()
            return setmetatable({}, {
                __index = function()
                    return true
                end,
            })
        end,
    }
end

function testcase.interval_doubles_until_capped()
    assert.equal(schedule.interval_for(0), 6 * HOUR)
    assert.equal(schedule.interval_for(1), 12 * HOUR)
    assert.equal(schedule.interval_for(2), 24 * HOUR)
    assert.equal(schedule.interval_for(3), 48 * HOUR)
    assert.equal(schedule.interval_for(4), 48 * HOUR)
    assert.equal(schedule.MAX_STEP, 3)
end

function testcase.should_run_respects_pause_due_and_force()
    local conn = db.open(':memory:')

    assert.equal(schedule.should_run(conn, {}, {
        now_iso = '2026-01-01T00:00:00Z',
    }), true)

    local due, reason = schedule.should_run(conn, {
        next_crawl_due = '2026-01-01T06:00:00Z',
    }, {
        now_iso = '2026-01-01T00:00:00Z',
    })
    assert.equal(due, false)
    assert.equal(reason, 'not due')

    assert.equal(schedule.should_run(conn, {
        next_crawl_due = '2026-01-01T06:00:00Z',
    }, {
        now_iso = '2026-01-01T07:00:00Z',
    }), true)

    conn:set_paused(true)
    local paused, preason = schedule.should_run(conn, {}, {
        now_iso = '2026-01-01T00:00:00Z',
    })
    assert.equal(paused, false)
    assert.equal(preason, 'paused')

    -- force bypasses pause
    assert.equal(schedule.should_run(conn, {}, {
        force = true,
    }), true)
    conn:close()
end

function testcase.next_state_resets_on_change()
    local epoch = 1800000000
    local state = schedule.next_state(true, 2, {
        now_epoch = epoch,
    })
    assert.equal(state.backoff_step, 0)
    assert.equal(state.next_crawl_due, os.date('!%Y-%m-%dT%H:%M:%SZ', epoch + 6 * HOUR))
end

function testcase.next_state_backs_off_without_change()
    local epoch = 1800000000
    local state = schedule.next_state(false, 0, {
        now_epoch = epoch,
    })
    assert.equal(state.backoff_step, 1)
    assert.equal(state.next_crawl_due, os.date('!%Y-%m-%dT%H:%M:%SZ', epoch + 12 * HOUR))
end

function testcase.next_state_caps_backoff_step()
    local state = schedule.next_state(false, 3, {
        now_epoch = 1800000000,
    })
    assert.equal(state.backoff_step, 3)
end

function testcase.run_source_skips_when_paused()
    local conn = db.open(':memory:')
    conn:set_paused(true)
    local gh = {
        list_repos = function()
            error('must not crawl while paused')
        end,
    }
    local result = schedule.run_source(conn, {
        host = 'github.com',
        owner = 'mah0x211',
    }, gh, {
        now_iso = '2026-01-01T00:00:00Z',
    })
    assert.equal(result.skipped, true)
    assert.equal(result.reason, 'paused')
    conn:close()
end

function testcase.run_source_skips_when_not_due()
    local conn = db.open(':memory:')
    local gh = {
        list_repos = function()
            error('must not crawl before due')
        end,
    }
    local result = schedule.run_source(conn, {
        host = 'github.com',
        owner = 'mah0x211',
        next_crawl_due = '2026-01-01T06:00:00Z',
    }, gh, {
        now_iso = '2026-01-01T00:00:00Z',
    })
    assert.equal(result.skipped, true)
    assert.equal(result.reason, 'not due')
    conn:close()
end

function testcase.run_source_crawls_and_resets_schedule_on_change()
    local conn = db.open(':memory:')
    conn:upsert_source({
        host = 'github.com',
        owner = 'mah0x211',
    })
    local source = conn:get_source('github.com', 'mah0x211')
    local gh = fake_gh({
        repos = {
            {
                name = 'lua-foo',
                default_branch = 'master',
                pushed_at = '2026-01-01T00:00:00Z',
                fork = false,
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

    local result = schedule.run_source(conn, source, gh, {
        now_epoch = 1800000000,
    })
    assert.equal(result.skipped, false)
    assert.equal(result.changed, true)
    assert.equal(#result.report.added, 1)

    local updated = conn:get_source('github.com', 'mah0x211')
    assert.equal(updated.backoff_step, 0)
    assert.not_nil(updated.last_crawl_at)
    assert.not_nil(updated.next_crawl_due)
    conn:close()
end

function testcase.run_source_keeps_watermark_and_retries_on_partial_failure()
    local conn = db.open(':memory:')
    conn:upsert_source({
        host = 'github.com',
        owner = 'mah0x211',
    })
    conn:update_source_crawl_state({
        host = 'github.com',
        owner = 'mah0x211',
        last_crawl_at = '2020-01-01T00:00:00Z',
        next_crawl_due = '2020-01-01T00:00:00Z',
        backoff_step = 2,
    })
    local source = conn:get_source('github.com', 'mah0x211')
    local gh = fake_gh({
        repos = {
            {
                name = 'lua-bad',
                default_branch = 'master',
                pushed_at = '2026-01-01T00:00:00Z',
                fork = false,
            },
        },
        trees = {
            ['lua-bad'] = {
                {
                    path = 'bad-1.0.0-1.rockspec',
                    sha = 'b1',
                },
            },
        },
    })
    gh.fetch_blobs = function()
        error('boom')
    end

    local result = schedule.run_source(conn, source, gh, {
        now_epoch = 1800000000,
        force = true,
    })
    assert.equal(result.skipped, false)
    assert.equal(#result.report.failed, 1)

    local updated = conn:get_source('github.com', 'mah0x211')
    -- the crawl watermark is left unadvanced so the failed repo is retried, and
    -- the schedule resets to a prompt retry instead of backing off
    assert.equal(updated.last_crawl_at, '2020-01-01T00:00:00Z')
    assert.equal(updated.backoff_step, 0)
    conn:close()
end

function testcase.run_source_backs_off_when_no_change()
    local conn = db.open(':memory:')
    conn:upsert_source({
        host = 'github.com',
        owner = 'mah0x211',
    })
    local source = conn:get_source('github.com', 'mah0x211')
    local gh = fake_gh({
        repos = {},
    })

    local result = schedule.run_source(conn, source, gh, {
        now_epoch = 1800000000,
    })
    assert.equal(result.changed, false)
    assert.equal(conn:get_source('github.com', 'mah0x211').backoff_step, 1)
    conn:close()
end

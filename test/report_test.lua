require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local report = require('rockup.report')

local function sync_result(report_tbl, extra)
    local r = {
        skipped = false,
        changed = true,
        report = report_tbl,
    }
    for k, v in pairs(extra or {}) do
        r[k] = v
    end
    return r
end

local function empty_report(overrides)
    local rep = {
        repos_scanned = 0,
        added = {},
        updated = {},
        deleted = {},
        rejected = {},
        invalid = {},
        failed = {},
    }
    for k, v in pairs(overrides or {}) do
        rep[k] = v
    end
    return rep
end

function testcase.format_sync_reports_changes_and_skips()
    local md = report.format_sync({
        changed = true,
        sources = {
            {
                owner = 'mah0x211',
                result = sync_result(empty_report({
                    repos_scanned = 3,
                    added = {
                        'a',
                        'b',
                    },
                    deleted = {
                        'c',
                    },
                })),
            },
            {
                owner = 'other',
                result = {
                    skipped = true,
                    reason = 'not due',
                },
            },
        },
    })
    assert.match(md, 'rockup sync')
    assert.match(md, '`mah0x211`: 3 repos scanned, %+2 ~0 %-1', false)
    assert.match(md, '`other`: skipped %(not due%)', false)
end

function testcase.format_sync_notes_no_changes()
    local md = report.format_sync({
        changed = false,
        sources = {},
    })
    assert.match(md, 'No changes')
end

function testcase.format_sync_reports_source_failures()
    local md = report.format_sync({
        changed = false,
        sources = {
            {
                owner = 'mah0x211',
                result = {
                    error = 'boom',
                },
            },
        },
    })
    assert.match(md, 'failed %(boom%)', false)
end

function testcase.format_sync_lists_rejected_and_invalid_details()
    local md = report.format_sync({
        changed = true,
        sources = {
            {
                owner = 'mah0x211',
                result = sync_result(empty_report({
                    repos_scanned = 2,
                    rejected = {
                        {
                            path = 'lua-foo/foo-1.0.0-1.rockspec',
                            reason = 'name/version foo 1.0.0-1 already published by mah0x211/lua-bar',
                        },
                    },
                    invalid = {
                        {
                            path = 'lua-baz/baz-2.0.0-1.rockspec',
                            reason = 'luarocks lint failed',
                        },
                    },
                })),
            },
        },
    })
    assert.match(md, 'rejected: lua%-foo/foo%-1.0.0%-1.rockspec %(name/version', false)
    assert.match(md, 'invalid: lua%-baz/baz%-2.0.0%-1.rockspec %(luarocks lint failed%)', false)
end

function testcase.format_sync_lists_failed_repositories()
    local md = report.format_sync({
        changed = true,
        sources = {
            {
                owner = 'mah0x211',
                result = sync_result(empty_report({
                    repos_scanned = 2,
                    added = {
                        'lua-good/good-1.0.0-1.rockspec',
                    },
                    failed = {
                        {
                            repo = 'lua-bad',
                            reason = 'git fetch failed',
                        },
                    },
                })),
            },
        },
    })
    assert.match(md, 'failed 1', false)
    assert.match(md, 'failed repos: lua%-bad %(git fetch failed%)', false)
end

function testcase.format_control_lists_sections()
    local md = report.format_control('exclude', {
        ignored = {
            'mah0x211/lua-foo',
        },
        unignored = {},
        added = {},
        updated = {},
        deleted = {
            'lua-foo/foo-1.0.0-1.rockspec',
        },
        rejected = {},
        invalid = {},
    })
    assert.match(md, '## exclude')
    assert.match(md, 'ignored %(1%): mah0x211/lua%-foo', false)
    assert.match(md, 'removed %(1%)', false)
end

function testcase.format_state_lists_excluded_and_sources()
    local md = report.format_state({
        {
            owner = 'mah0x211',
            repo = 'lua-foo',
        },
    }, {
        {
            host = 'github.com',
            owner = 'mah0x211',
            enabled = 1,
        },
    })
    assert.match(md, 'excluded repositories: 1')
    assert.match(md, '`mah0x211/lua%-foo`', false)
    assert.match(md, 'crawl sources: 1')
    assert.match(md, 'enabled')
end

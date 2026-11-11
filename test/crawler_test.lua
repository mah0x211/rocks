require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local db = require('rockup.db')
local crawler = require('rockup.crawler')

local HOST = 'github.com'
local OWNER = 'mah0x211'

--- Builds a GitHub stub from static fixtures.
local function fake_gh(cfg)
    return {
        list_repos = function(_, _)
            return cfg.repos or {}
        end,
        list_rockspecs = function(_, _, repo, ref)
            local trees = cfg.trees or {}
            if cfg.trees_by_ref then
                return (cfg.trees_by_ref[repo] or {})[ref] or {}
            end
            return trees[repo] or {}
        end,
        fetch_blobs = function(_, _, _, shas)
            local out = {}
            for _, sha in ipairs(shas) do
                out[sha] = (cfg.blobs and cfg.blobs[sha]) or ('content-' .. sha)
            end
            return out
        end,
        default_branch = function(_, _, repo)
            return (cfg.default_branches and cfg.default_branches[repo]) or 'master'
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

local function repo(name, pushed_at, extra)
    local r = {
        name = name,
        default_branch = 'master',
        pushed_at = pushed_at or '2026-01-01T00:00:00Z',
        fork = false,
    }
    for k, v in pairs(extra or {}) do
        r[k] = v
    end
    return r
end

local function seed_spec(conn, name, version, repo_name, blob_sha, managed)
    conn:upsert_rockspec({
        host = HOST,
        owner = OWNER,
        repo = repo_name,
        filename = string.format('%s-%s.rockspec', name, version),
        name = name,
        version = version,
        blob_sha = blob_sha,
        managed = managed,
    })
end

function testcase.initial_crawl_adds_all_rockspecs()
    local conn = db.open(':memory:')
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
        },
        trees = {
            ['lua-foo'] = {
                {
                    path = 'rockspecs/foo-1.0.0-1.rockspec',
                    sha = 's1',
                },
                {
                    path = 'rockspecs/foo-1.1.0-1.rockspec',
                    sha = 's2',
                },
            },
        },
    })

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.added, 2)
    assert.equal(#report.deleted, 0)
    assert.equal(conn:count_active_rockspecs(), 2)
    conn:close()
end

function testcase.records_invalid_when_blob_content_is_missing()
    local conn = db.open(':memory:')
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
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
    -- The fetch returns without the requested blob, so the upsert has no content.
    gh.fetch_blobs = function()
        return {}
    end

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.added, 0)
    assert.equal(#report.invalid, 1)
    assert.match(report.invalid[1].reason, 'content could not be fetched')
    assert.equal(conn:count_active_rockspecs(), 0)
    conn:close()
end

function testcase.isolates_a_failing_repository_and_crawls_the_rest()
    local conn = db.open(':memory:')
    local gh = fake_gh({
        repos = {
            repo('lua-bad'),
            repo('lua-good'),
        },
        trees = {
            ['lua-bad'] = {
                {
                    path = 'bad-1.0.0-1.rockspec',
                    sha = 'b1',
                },
            },
            ['lua-good'] = {
                {
                    path = 'good-1.0.0-1.rockspec',
                    sha = 'g1',
                },
            },
        },
    })
    gh.fetch_blobs = function(_, _, name, shas)
        if name == 'lua-bad' then
            error('boom fetching ' .. name)
        end
        local out = {}
        for _, sha in ipairs(shas) do
            out[sha] = 'content-' .. sha
        end
        return out
    end

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.failed, 1)
    assert.equal(report.failed[1].repo, 'lua-bad')
    assert.match(report.failed[1].reason, 'boom fetching lua-bad')
    -- the healthy repository is still crawled despite the earlier failure
    assert.equal(#report.added, 1)
    assert.equal(report.added[1], 'lua-good/good-1.0.0-1.rockspec')
    assert.equal(conn:count_active_rockspecs(), 1)
    conn:close()
end

function testcase.mixed_repo_applies_delete_and_add_atomically()
    local conn = db.open(':memory:')
    seed_spec(conn, 'foo', '0.9.0-1', 'lua-foo', 'old')
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
        },
        trees = {
            ['lua-foo'] = {
                {
                    path = 'foo-0.9.1-1.rockspec',
                    sha = 'new',
                },
            },
        },
    })

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.failed, 0)
    assert.equal(#report.added, 1)
    assert.equal(report.added[1], 'lua-foo/foo-0.9.1-1.rockspec')
    assert.equal(#report.deleted, 1)
    assert.equal(report.deleted[1], 'lua-foo/foo-0.9.0-1.rockspec')
    assert.equal(conn:count_active_rockspecs(), 1)
    conn:close()
end

function testcase.mixed_repo_rolls_back_deletion_when_fetch_fails()
    local conn = db.open(':memory:')
    seed_spec(conn, 'foo', '0.9.0-1', 'lua-foo', 'old')
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
        },
        trees = {
            ['lua-foo'] = {
                {
                    path = 'foo-0.9.1-1.rockspec',
                    sha = 'new',
                },
            },
        },
    })
    gh.fetch_blobs = function()
        error('boom')
    end

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.failed, 1)
    assert.equal(report.failed[1].repo, 'lua-foo')
    -- the paired deletion is rolled back with the failed addition: no gap
    assert.equal(#report.deleted, 0)
    assert.equal(#report.added, 0)
    assert.equal(conn:count_active_rockspecs(), 1)
    assert.is_nil(conn:get_rockspec(HOST, OWNER, 'lua-foo', 'foo-0.9.0-1.rockspec').deleted_at)
    conn:close()
end

function testcase.updates_when_blob_sha_changes()
    local conn = db.open(':memory:')
    seed_spec(conn, 'foo', '1.0.0-1', 'lua-foo', 'old')
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
        },
        trees = {
            ['lua-foo'] = {
                {
                    path = 'foo-1.0.0-1.rockspec',
                    sha = 'new',
                },
            },
        },
    })

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.updated, 1)
    assert.equal(#report.added, 0)
    local row = conn:get_rockspec(HOST, OWNER, 'lua-foo', 'foo-1.0.0-1.rockspec')
    assert.equal(row.blob_sha, 'new')
    conn:close()
end

function testcase.unchanged_blob_is_skipped()
    local conn = db.open(':memory:')
    seed_spec(conn, 'foo', '1.0.0-1', 'lua-foo', 'same')
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
        },
        trees = {
            ['lua-foo'] = {
                {
                    path = 'foo-1.0.0-1.rockspec',
                    sha = 'same',
                },
            },
        },
    })
    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.added, 0)
    assert.equal(#report.updated, 0)
    conn:close()
end

function testcase.in_repo_removed_rockspec_is_soft_deleted()
    local conn = db.open(':memory:')
    seed_spec(conn, 'foo', '1.0.0-1', 'lua-foo', 's1')
    seed_spec(conn, 'foo', '1.1.0-1', 'lua-foo', 's2')
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
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

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.deleted, 1)
    assert.equal(report.deleted[1], 'lua-foo/foo-1.1.0-1.rockspec')
    assert.equal(conn:count_active_rockspecs(), 1)
    conn:close()
end

function testcase.reconciliation_deletes_vanished_repository()
    local conn = db.open(':memory:')
    seed_spec(conn, 'gone', '1.0.0-1', 'lua-gone', 's1')
    -- lua-gone is absent from the current repository listing
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
        },
        trees = {
            ['lua-foo'] = {},
        },
    })

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.deleted, 1)
    assert.equal(report.deleted[1], 'lua-gone/gone-1.0.0-1.rockspec')
    assert.equal(conn:count_active_rockspecs(), 0)
    conn:close()
end

function testcase.grandfathered_rows_are_not_reconciled()
    local conn = db.open(':memory:')
    seed_spec(conn, 'legacy', '1.0.0-1', 'lua-legacy', 's1', false)
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
        },
    })
    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.deleted, 0)
    assert.equal(conn:count_active_rockspecs(), 1)
    conn:close()
end

function testcase.grandfathered_rockspec_absent_from_tree_is_kept()
    local conn = db.open(':memory:')
    -- an old grandfathered version no longer present in the repository tree
    seed_spec(conn, 'foo', '0.1.0-1', 'lua-foo', 'old', false)
    -- a managed version also absent from the tree
    seed_spec(conn, 'foo', '0.2.0-1', 'lua-foo', 'mid', true)
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
        },
        trees = {
            ['lua-foo'] = {
                {
                    path = 'foo-0.3.0-1.rockspec',
                    sha = 'new',
                },
            },
        },
    })

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.added, 1)
    assert.equal(#report.deleted, 1)
    assert.equal(report.deleted[1], 'lua-foo/foo-0.2.0-1.rockspec')
    -- grandfathered row is preserved, managed row is removed
    assert.is_nil(conn:get_rockspec(HOST, OWNER, 'lua-foo', 'foo-0.1.0-1.rockspec').deleted_at)
    assert.not_nil(conn:get_rockspec(HOST, OWNER, 'lua-foo', 'foo-0.2.0-1.rockspec').deleted_at)
    assert.equal(conn:count_active_rockspecs(), 2)
    conn:close()
end

function testcase.deletion_guard_aborts_without_applying()
    local conn = db.open(':memory:')
    for i = 1, 100 do
        seed_spec(conn, 'pkg' .. i, '1.0.0-1', 'lua-big', 's' .. i)
    end
    -- An empty listing would reconcile every rockspec away; the guard must stop it.
    local gh = fake_gh({
        repos = {},
    })

    local err = assert.throws(function()
        crawler.discover_source(conn, {
            host = HOST,
            owner = OWNER,
        }, gh)
    end)
    assert.match(err, 'deletion guard')
    assert.equal(conn:count_active_rockspecs(), 100)
    conn:close()
end

function testcase.collision_with_other_repo_is_rejected()
    local conn = db.open(':memory:')
    seed_spec(conn, 'foo', '1.0.0-1', 'lua-other', 's0')
    -- both repositories are live: lua-other already owns the name/version and
    -- lua-foo tries to publish the same one, which must be rejected as a hijack.
    local gh = fake_gh({
        repos = {
            repo('lua-other'),
            repo('lua-foo'),
        },
        trees = {
            ['lua-other'] = {
                {
                    path = 'foo-1.0.0-1.rockspec',
                    sha = 's0',
                },
            },
            ['lua-foo'] = {
                {
                    path = 'foo-1.0.0-1.rockspec',
                    sha = 's1',
                },
            },
        },
    })

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.added, 0)
    assert.equal(#report.rejected, 1)
    assert.match(report.rejected[1].reason, 'already published by')
    assert.is_nil(conn:get_rockspec(HOST, OWNER, 'lua-foo', 'foo-1.0.0-1.rockspec'))
    assert.not_nil(conn:get_rockspec(HOST, OWNER, 'lua-other', 'foo-1.0.0-1.rockspec'))
    conn:close()
end

function testcase.ignored_repository_is_skipped()
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
        repos = {
            repo('lua-foo'),
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

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(report.repos_scanned, 0)
    assert.equal(#report.added, 0)
    conn:close()
end

function testcase.forks_are_skipped_by_default()
    local conn = db.open(':memory:')
    local gh = fake_gh({
        repos = {
            repo('lua-fork', '2026-01-01T00:00:00Z', {
                fork = true,
            }),
        },
        trees = {
            ['lua-fork'] = {
                {
                    path = 'foo-1.0.0-1.rockspec',
                    sha = 's1',
                },
            },
        },
    })
    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(report.repos_scanned, 0)
    conn:close()
end

function testcase.date_gate_skips_unchanged_repositories()
    local conn = db.open(':memory:')
    local gh = fake_gh({
        repos = {
            repo('lua-foo', '2026-01-01T00:00:00Z'),
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
    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
        last_crawl_at = '2026-06-01T00:00:00Z',
    }, gh)
    assert.equal(report.repos_scanned, 0)
    assert.equal(#report.added, 0)
    conn:close()
end

function testcase.validator_rejection_is_recorded_as_invalid()
    local conn = db.open(':memory:')
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
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
    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh, {
        validate = function()
            return false, 'missing tag'
        end,
    })
    assert.equal(#report.added, 0)
    assert.equal(#report.invalid, 1)
    assert.match(report.invalid[1].reason, 'missing tag')
    assert.equal(conn:count_active_rockspecs(), 0)
    conn:close()
end

function testcase.validator_metadata_sets_provenance()
    local conn = db.open(':memory:')
    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
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
    crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh, {
        validate = function(rec)
            return true, nil, {
                source_url = 'git+https://github.com/mah0x211/lua-foo.git',
                source_host = rec.host,
                source_owner = rec.owner,
                source_repo = rec.repo,
            }
        end,
    })
    local row = conn:get_rockspec(HOST, OWNER, 'lua-foo', 'foo-1.0.0-1.rockspec')
    assert.equal(row.source_url, 'git+https://github.com/mah0x211/lua-foo.git')
    conn:close()
end

function testcase.discover_repo_crawls_single_repository()
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
    local report = crawler.discover_repo(conn, {
        host = HOST,
        owner = OWNER,
        repo = 'lua-foo',
    }, gh)
    assert.equal(#report.added, 1)
    assert.equal(conn:count_active_rockspecs(), 1)
    conn:close()
end

function testcase.discover_repo_uses_resolved_default_branch()
    local conn = db.open(':memory:')
    -- the repository's default branch is not 'master'; reading the wrong branch
    -- would return an empty tree and find nothing.
    local gh = fake_gh({
        default_branches = {
            ['lua-foo'] = 'main',
        },
        trees_by_ref = {
            ['lua-foo'] = {
                main = {
                    {
                        path = 'foo-1.0.0-1.rockspec',
                        sha = 's1',
                    },
                },
                master = {},
            },
        },
    })
    local report = crawler.discover_repo(conn, {
        host = HOST,
        owner = OWNER,
        repo = 'lua-foo',
    }, gh)
    assert.equal(#report.added, 1)
    assert.equal(conn:count_active_rockspecs(), 1)
    conn:close()
end

function testcase.crawl_revives_soft_deleted_rockspec()
    local conn = db.open(':memory:')
    seed_spec(conn, 'foo', '1.0.0-1', 'lua-foo', 's1')
    conn:soft_delete_rockspec({
        host = HOST,
        owner = OWNER,
        repo = 'lua-foo',
        filename = 'foo-1.0.0-1.rockspec',
    })
    assert.equal(conn:count_active_rockspecs(), 0)

    local gh = fake_gh({
        repos = {
            repo('lua-foo'),
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
    crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(conn:count_active_rockspecs(), 1)
    conn:close()
end

function testcase.repository_rename_moves_rockspec_without_dropping_it()
    local conn = db.open(':memory:')
    -- the package is currently published from the old repository name
    seed_spec(conn, 'foo', '1.0.0-1', 'lua-old', 's1')
    -- the old repository has vanished and a new one publishes the same rockspec
    local gh = fake_gh({
        repos = {
            repo('lua-new'),
        },
        trees = {
            ['lua-new'] = {
                {
                    path = 'foo-1.0.0-1.rockspec',
                    sha = 's1',
                },
            },
        },
    })

    local report = crawler.discover_source(conn, {
        host = HOST,
        owner = OWNER,
    }, gh)
    assert.equal(#report.added, 1)
    assert.equal(#report.deleted, 1)
    assert.equal(#report.rejected, 0)
    assert.equal(conn:count_active_rockspecs(), 1)
    local row = conn:get_rockspec(HOST, OWNER, 'lua-new', 'foo-1.0.0-1.rockspec')
    assert.is_nil(row.deleted_at)
    conn:close()
end

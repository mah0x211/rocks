require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local db = require('rockup.db')

local function sample_spec(overrides)
    local spec = {
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
        filename = 'foo-1.0.0-1.rockspec',
        name = 'foo',
        version = '1.0.0-1',
        blob_sha = 'sha-a',
        source_url = 'git+https://github.com/mah0x211/lua-foo.git',
        source_host = 'github.com',
        source_owner = 'mah0x211',
        source_repo = 'lua-foo',
    }
    for k, v in pairs(overrides or {}) do
        spec[k] = v
    end
    return spec
end

function testcase.creates_tables_and_persists_meta()
    local conn = db.open(':memory:')
    local rows = conn.conn:all(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")
    local names = {}
    for _, r in ipairs(rows) do
        names[r.name] = true
    end
    for _, t in ipairs({
        'meta',
        'repos',
        'rockspecs',
        'sources',
    }) do
        assert.equal(names[t], true)
    end

    assert.is_nil(conn:get_meta('missing'))
    conn:set_meta('k', 'v')
    assert.equal(conn:get_meta('k'), 'v')
    conn:set_meta('k', 'v2')
    assert.equal(conn:get_meta('k'), 'v2')
    conn:close()
end

function testcase.pause_flag_defaults_false_and_toggles()
    local conn = db.open(':memory:')
    assert.equal(conn:is_paused(), false)
    conn:set_paused(true)
    assert.equal(conn:is_paused(), true)
    conn:set_paused(false)
    assert.equal(conn:is_paused(), false)
    conn:close()
end

function testcase.sources_upsert_list_disable_and_crawl_state()
    local conn = db.open(':memory:')
    conn:upsert_source({
        host = 'github.com',
        owner = 'mah0x211',
    })
    conn:upsert_source({
        host = 'github.com',
        owner = 'other',
        enabled = false,
    })

    local enabled = conn:list_enabled_sources()
    assert.equal(#enabled, 1)
    assert.equal(enabled[1].owner, 'mah0x211')
    assert.equal(enabled[1].api_base, 'https://api.github.com')

    conn:set_source_enabled('github.com', 'other', true)
    assert.equal(#conn:list_enabled_sources(), 2)

    conn:update_source_crawl_state({
        host = 'github.com',
        owner = 'mah0x211',
        last_crawl_at = '2026-01-01T00:00:00Z',
        next_crawl_due = '2026-01-01T06:00:00Z',
        backoff_step = 2,
    })
    local s = conn:get_source('github.com', 'mah0x211')
    assert.equal(s.last_crawl_at, '2026-01-01T00:00:00Z')
    assert.equal(s.next_crawl_due, '2026-01-01T06:00:00Z')
    assert.equal(s.backoff_step, 2)
    conn:close()
end

function testcase.repos_upsert_and_ignore_toggle()
    local conn = db.open(':memory:')
    conn:upsert_repo({
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
        default_branch = 'master',
        pushed_at = '2026-01-01T00:00:00Z',
    })
    conn:upsert_repo({
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
        default_branch = 'main',
        pushed_at = '2026-02-01T00:00:00Z',
    })
    local repo = conn:get_repo('github.com', 'mah0x211', 'lua-foo')
    assert.equal(repo.default_branch, 'main')
    assert.equal(repo.pushed_at, '2026-02-01T00:00:00Z')
    assert.equal(repo.ignore, 0)

    local changed = conn:set_repo_ignore({
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
        ignore = true,
    })
    assert.equal(changed, 1)
    assert.equal(conn:get_repo('github.com', 'mah0x211', 'lua-foo').ignore, 1)
    assert.equal(#conn:list_repos_by_owner('github.com', 'mah0x211'), 1)
    conn:close()
end

function testcase.rockspec_insert_then_soft_delete()
    local conn = db.open(':memory:')
    conn:upsert_rockspec(sample_spec())
    assert.equal(conn:count_active_rockspecs(), 1)
    assert.equal(#conn:list_active_rockspecs(), 1)

    local changed = conn:soft_delete_rockspec({
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
        filename = 'foo-1.0.0-1.rockspec',
    })
    assert.equal(changed, 1)
    assert.equal(conn:count_active_rockspecs(), 0)
    local row = conn:get_rockspec('github.com', 'mah0x211', 'lua-foo', 'foo-1.0.0-1.rockspec')
    assert.not_nil(row.deleted_at)

    -- soft deleting again is a no-op
    assert.equal(conn:soft_delete_rockspec({
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
        filename = 'foo-1.0.0-1.rockspec',
    }), 0)
    conn:close()
end

function testcase.reupsert_revives_soft_deleted_row()
    local conn = db.open(':memory:')
    conn:upsert_rockspec(sample_spec({
        blob_sha = 'sha-a',
    }))
    conn:soft_delete_rockspec({
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
        filename = 'foo-1.0.0-1.rockspec',
    })

    conn:upsert_rockspec(sample_spec({
        blob_sha = 'sha-b',
    }))
    local row = conn:get_rockspec('github.com', 'mah0x211', 'lua-foo', 'foo-1.0.0-1.rockspec')
    assert.is_nil(row.deleted_at)
    assert.equal(row.blob_sha, 'sha-b')
    assert.equal(conn:count_active_rockspecs(), 1)
    assert.equal(conn.conn:get('SELECT COUNT(*) AS c FROM rockspecs').c, 1)
    conn:close()
end

function testcase.rockspec_content_blob_roundtrip()
    local conn = db.open(':memory:')
    local content = 'package = "foo"\nversion = "1.0.0-1"\n'
    conn:upsert_rockspec(sample_spec({
        content = content,
        file_size = #content,
    }))
    local row = conn:get_rockspec('github.com', 'mah0x211', 'lua-foo', 'foo-1.0.0-1.rockspec')
    assert.equal(row.content, content)
    assert.equal(row.file_size, #content)
    conn:close()
end

function testcase.managed_flag_defaults_1_and_grandfathers_to_0()
    local conn = db.open(':memory:')
    conn:upsert_rockspec(sample_spec())
    assert.equal(conn:get_rockspec('github.com', 'mah0x211', 'lua-foo', 'foo-1.0.0-1.rockspec').managed, 1)

    conn:upsert_rockspec(sample_spec({
        repo = 'legacy',
        managed = false,
    }))
    assert.equal(conn:get_rockspec('github.com', 'mah0x211', 'legacy', 'foo-1.0.0-1.rockspec').managed, 0)
    conn:close()
end

function testcase.list_rockspecs_by_repo_includes_or_excludes_deleted()
    local conn = db.open(':memory:')
    conn:upsert_rockspec(sample_spec({
        filename = 'foo-1.0.0-1.rockspec',
    }))
    conn:upsert_rockspec(sample_spec({
        filename = 'foo-1.1.0-1.rockspec',
        version = '1.1.0-1',
    }))
    conn:soft_delete_rockspec({
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
        filename = 'foo-1.0.0-1.rockspec',
    })
    assert.equal(#conn:list_rockspecs_by_repo('github.com', 'mah0x211', 'lua-foo'), 1)
    assert.equal(#conn:list_rockspecs_by_repo('github.com', 'mah0x211', 'lua-foo', {
        include_deleted = true,
    }), 2)
    conn:close()
end

function testcase.deletion_guard_allows_small_and_blocks_large()
    local ok = db.check_deletion_guard(10, 100)
    assert.equal(ok, true)
    assert.equal(db.check_deletion_guard(0, 0), true)

    local blocked, reason = db.check_deletion_guard(30, 100)
    assert.equal(blocked, false)
    assert.match(reason, 'exceeds guard limit')

    assert.equal(db.check_deletion_guard(20, 200), true)

    local no_state = db.check_deletion_guard(50, 0)
    assert.equal(no_state, false)

    assert.equal(db.check_deletion_guard(2, 10, {
        floor = 0,
        max_fraction = 0.1,
    }), false)
    assert.equal(db.check_deletion_guard(1, 100, {
        floor = 0,
        max_fraction = 0.1,
    }), true)
end

function testcase.collision_detects_other_repo_same_name_version()
    local conn = db.open(':memory:')
    conn:upsert_rockspec(sample_spec())

    local conflict = conn:find_conflict({
        name = 'foo',
        version = '1.0.0-1',
        host = 'github.com',
        owner = 'evil',
        repo = 'lua-foo',
    })
    assert.not_nil(conflict)
    assert.equal(conflict.owner, 'mah0x211')

    -- same repo updating its own rockspec is not a conflict
    assert.is_nil(conn:find_conflict({
        name = 'foo',
        version = '1.0.0-1',
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
    }))

    -- soft-deleted rows are ignored
    conn:soft_delete_rockspec({
        host = 'github.com',
        owner = 'mah0x211',
        repo = 'lua-foo',
        filename = 'foo-1.0.0-1.rockspec',
    })
    assert.is_nil(conn:find_conflict({
        name = 'foo',
        version = '1.0.0-1',
        host = 'github.com',
        owner = 'other',
        repo = 'lua-foo',
    }))
    conn:close()
end

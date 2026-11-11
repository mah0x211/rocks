--
-- MIT License
--
-- Copyright (c) 2026 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--
--- rocks.db data-access layer and safety primitives.
---
--- Owns the authoritative registry state schema driven by the crawler
--- (sources -> repos -> rockspecs) plus operational metadata, and the safety
--- primitives (mass-deletion guard, provenance collision detection) that protect
--- the published registry from corruption.
local sqlite = require('rockup.sqlite')

local DEFAULT_DB_PATH = 'rocks.db'

--- Returns the current time as an ISO-8601 UTC string. All timestamps stored in
--- rocks.db use this format so comparisons with GitHub timestamps are unambiguous.
--- @return string
local function now_iso()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local SCHEMA_STATEMENTS = {
    -- Crawl targets. The periodic crawler iterates enabled sources instead of a
    -- hard-coded account. Keep-alive scheduling state is held per source.
    [[CREATE TABLE IF NOT EXISTS sources (
        id INTEGER PRIMARY KEY,
        host TEXT NOT NULL,
        owner TEXT NOT NULL,
        api_base TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        last_crawl_at TEXT,
        next_crawl_due TEXT,
        backoff_step INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(host, owner)
    )]],
    -- Repositories discovered under a source. pushed_at records the last seen
    -- value so unchanged repositories can be skipped on subsequent crawls.
    [[CREATE TABLE IF NOT EXISTS repos (
        id INTEGER PRIMARY KEY,
        host TEXT NOT NULL,
        owner TEXT NOT NULL,
        repo TEXT NOT NULL,
        default_branch TEXT,
        pushed_at TEXT,
        ignore INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(host, owner, repo)
    )]],
    -- Rockspecs that make up the registry. deleted_at IS NULL means active
    -- (served). managed=0 marks grandfathered entries that have no known source
    -- repository and are therefore excluded from automatic deletion.
    [[CREATE TABLE IF NOT EXISTS rockspecs (
        id INTEGER PRIMARY KEY,
        host TEXT NOT NULL,
        owner TEXT NOT NULL,
        repo TEXT NOT NULL,
        filename TEXT NOT NULL,
        name TEXT NOT NULL,
        version TEXT NOT NULL,
        blob_sha TEXT,
        commit_sha TEXT,
        file_size INTEGER,
        content BLOB,
        source_url TEXT,
        source_host TEXT,
        source_owner TEXT,
        source_repo TEXT,
        managed INTEGER NOT NULL DEFAULT 1,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(host, owner, repo, filename)
    )]],
    -- Global operational state (e.g. the paused flag).
    [[CREATE TABLE IF NOT EXISTS meta (
        key TEXT PRIMARY KEY,
        value TEXT
    )]],
    [[CREATE INDEX IF NOT EXISTS idx_rockspecs_name_version
        ON rockspecs(name, version)]],
    [[CREATE INDEX IF NOT EXISTS idx_rockspecs_repo
        ON rockspecs(host, owner, repo)]],
}

--- @class DB
local DB = {}
DB.__index = DB

--- Creates the registry schema if it does not exist (idempotent).
function DB:init_schema()
    for _, statement in ipairs(SCHEMA_STATEMENTS) do
        self.conn:exec(statement)
    end
end

--- Runs fn within a transaction, rolling back on error.
--- @param fn function
--- @return any
function DB:transaction(fn)
    return self.conn:transaction(fn)
end

--- Closes the underlying connection.
function DB:close()
    self.conn:close()
end

----------------------------------------------------------------------- meta --

--- @param key string
--- @return string|nil
function DB:get_meta(key)
    local row = self.conn:get('SELECT value FROM meta WHERE key = $key', {
        key = key,
    })
    return row and row.value or nil
end

--- @param key string
--- @param value string|nil
function DB:set_meta(key, value)
    self.conn:run([[
        INSERT INTO meta(key, value) VALUES($key, $value)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
    ]], {
        key = key,
        value = value,
    })
end

--- @return boolean
function DB:is_paused()
    return self:get_meta('paused') == 'true'
end

--- @param paused boolean
function DB:set_paused(paused)
    self:set_meta('paused', paused and 'true' or 'false')
end

-------------------------------------------------------------------- sources --

--- @param source table {host, owner, api_base?, enabled?}
function DB:upsert_source(source)
    local at = now_iso()
    self.conn:run([[
        INSERT INTO sources(host, owner, api_base, enabled, created_at, updated_at)
        VALUES($host, $owner, $api_base, $enabled, $at, $at)
        ON CONFLICT(host, owner) DO UPDATE SET
            api_base = excluded.api_base,
            enabled = excluded.enabled,
            updated_at = excluded.updated_at
    ]], {
        host = source.host,
        owner = source.owner,
        api_base = source.api_base or 'https://api.github.com',
        enabled = source.enabled == false and 0 or 1,
        at = at,
    })
end

--- @return table|nil
function DB:get_source(host, owner)
    return self.conn:get('SELECT * FROM sources WHERE host = $host AND owner = $owner', {
        host = host,
        owner = owner,
    })
end

--- @return table[]
function DB:list_enabled_sources()
    return self.conn:all('SELECT * FROM sources WHERE enabled = 1 ORDER BY host, owner')
end

--- @return table[]
function DB:list_sources()
    return self.conn:all('SELECT * FROM sources ORDER BY host, owner')
end

--- @param enabled boolean
function DB:set_source_enabled(host, owner, enabled)
    self.conn:run([[
        UPDATE sources SET enabled = $enabled, updated_at = $at
        WHERE host = $host AND owner = $owner
    ]], {
        host = host,
        owner = owner,
        enabled = enabled and 1 or 0,
        at = now_iso(),
    })
end

--- @param state table {host, owner, last_crawl_at?, next_crawl_due?, backoff_step?}
function DB:update_source_crawl_state(state)
    self.conn:run([[
        UPDATE sources SET
            last_crawl_at = $last_crawl_at,
            next_crawl_due = $next_crawl_due,
            backoff_step = $backoff_step,
            updated_at = $at
        WHERE host = $host AND owner = $owner
    ]], {
        host = state.host,
        owner = state.owner,
        last_crawl_at = state.last_crawl_at,
        next_crawl_due = state.next_crawl_due,
        backoff_step = state.backoff_step or 0,
        at = now_iso(),
    })
end

---------------------------------------------------------------------- repos --

--- @param repo table {host, owner, repo, default_branch?, pushed_at?}
function DB:upsert_repo(repo)
    local at = now_iso()
    self.conn:run([[
        INSERT INTO repos(host, owner, repo, default_branch, pushed_at, created_at, updated_at)
        VALUES($host, $owner, $repo, $default_branch, $pushed_at, $at, $at)
        ON CONFLICT(host, owner, repo) DO UPDATE SET
            default_branch = excluded.default_branch,
            pushed_at = excluded.pushed_at,
            updated_at = excluded.updated_at
    ]], {
        host = repo.host,
        owner = repo.owner,
        repo = repo.repo,
        default_branch = repo.default_branch,
        pushed_at = repo.pushed_at,
        at = at,
    })
end

--- @return table|nil
function DB:get_repo(host, owner, repo)
    return self.conn:get('SELECT * FROM repos WHERE host = $host AND owner = $owner AND repo = $repo', {
        host = host,
        owner = owner,
        repo = repo,
    })
end

--- @return table[]
function DB:list_repos_by_owner(host, owner)
    return self.conn:all('SELECT * FROM repos WHERE host = $host AND owner = $owner ORDER BY repo', {
        host = host,
        owner = owner,
    })
end

--- @return table[]
function DB:list_ignored_repos()
    return self.conn:all('SELECT * FROM repos WHERE ignore = 1 ORDER BY host, owner, repo')
end

--- @param params table {host, owner, repo, ignore}
--- @return integer rows changed
function DB:set_repo_ignore(params)
    local result = self.conn:run([[
        UPDATE repos SET ignore = $ignore, updated_at = $at
        WHERE host = $host AND owner = $owner AND repo = $repo
    ]], {
        host = params.host,
        owner = params.owner,
        repo = params.repo,
        ignore = params.ignore and 1 or 0,
        at = now_iso(),
    })
    return result.changes
end

------------------------------------------------------------------ rockspecs --

--- Inserts or updates (reviving if soft-deleted) a rockspec row. On conflict the
--- existing row keyed by (host, owner, repo, filename) is updated and deleted_at
--- is cleared, so a previously removed rockspec that reappears is revived in
--- place rather than duplicated.
--- @param rec table
function DB:upsert_rockspec(rec)
    local at = rec.updated_at or now_iso()
    self.conn:run([[
        INSERT INTO rockspecs(
            host, owner, repo, filename, name, version, blob_sha, commit_sha,
            file_size, content, source_url, source_host, source_owner, source_repo,
            managed, deleted_at, created_at, updated_at
        ) VALUES(
            $host, $owner, $repo, $filename, $name, $version, $blob_sha, $commit_sha,
            $file_size, $content, $source_url, $source_host, $source_owner, $source_repo,
            $managed, NULL, $at, $at
        )
        ON CONFLICT(host, owner, repo, filename) DO UPDATE SET
            name = excluded.name,
            version = excluded.version,
            blob_sha = excluded.blob_sha,
            commit_sha = excluded.commit_sha,
            file_size = excluded.file_size,
            content = excluded.content,
            source_url = excluded.source_url,
            source_host = excluded.source_host,
            source_owner = excluded.source_owner,
            source_repo = excluded.source_repo,
            managed = excluded.managed,
            deleted_at = NULL,
            updated_at = excluded.updated_at
    ]], {
        host = rec.host,
        owner = rec.owner,
        repo = rec.repo,
        filename = rec.filename,
        name = rec.name,
        version = rec.version,
        blob_sha = rec.blob_sha,
        commit_sha = rec.commit_sha,
        file_size = rec.file_size,
        content = rec.content ~= nil and sqlite.blob(rec.content) or nil,
        source_url = rec.source_url,
        source_host = rec.source_host,
        source_owner = rec.source_owner,
        source_repo = rec.source_repo,
        managed = rec.managed == false and 0 or 1,
        at = at,
    })
end

--- Soft-deletes an active rockspec by setting deleted_at.
--- @param params table {host, owner, repo, filename, at?}
--- @return integer rows changed
function DB:soft_delete_rockspec(params)
    local deleted_at = params.at or now_iso()
    local result = self.conn:run([[
        UPDATE rockspecs SET deleted_at = $deleted_at, updated_at = $deleted_at
        WHERE host = $host AND owner = $owner AND repo = $repo
          AND filename = $filename AND deleted_at IS NULL
    ]], {
        host = params.host,
        owner = params.owner,
        repo = params.repo,
        filename = params.filename,
        deleted_at = deleted_at,
    })
    return result.changes
end

--- Revives soft-deleted grandfathered (managed=0) rockspecs for a repository, so
--- re-including a previously excluded repository restores the published versions
--- that have no counterpart in its current tree.
--- @param host string
--- @param owner string
--- @param repo string
--- @return integer rows changed
function DB:revive_grandfathered(host, owner, repo)
    local result = self.conn:run([[
        UPDATE rockspecs SET deleted_at = NULL, updated_at = $at
        WHERE host = $host AND owner = $owner AND repo = $repo
          AND managed = 0 AND deleted_at IS NOT NULL
    ]], {
        host = host,
        owner = owner,
        repo = repo,
        at = now_iso(),
    })
    return result.changes
end

--- @return table|nil
function DB:get_rockspec(host, owner, repo, filename)
    return self.conn:get([[
        SELECT * FROM rockspecs
        WHERE host = $host AND owner = $owner AND repo = $repo AND filename = $filename
    ]], {
        host = host,
        owner = owner,
        repo = repo,
        filename = filename,
    })
end

--- @return table[]
function DB:list_active_rockspecs()
    return self.conn:all('SELECT * FROM rockspecs WHERE deleted_at IS NULL ORDER BY name, version')
end

--- @return integer
function DB:count_active_rockspecs()
    return self.conn:get('SELECT COUNT(*) AS c FROM rockspecs WHERE deleted_at IS NULL').c
end

--- @param options table|nil {include_deleted?}
--- @return table[]
function DB:list_rockspecs_by_repo(host, owner, repo, options)
    options = options or {}
    local where = options.include_deleted and '' or ' AND deleted_at IS NULL'
    return self.conn:all([[
        SELECT * FROM rockspecs
        WHERE host = $host AND owner = $owner AND repo = $repo]] .. where .. [[
        ORDER BY filename
    ]], {
        host = host,
        owner = owner,
        repo = repo,
    })
end

--- Finds an active rockspec that collides on (name, version) with a different
--- provenance (host, owner, repo). Used to reject a repository attempting to
--- shadow a package name already published by another repository.
--- @param candidate table {name, version, host, owner, repo}
--- @return table|nil the conflicting row, if any
function DB:find_conflict(candidate)
    return self.conn:get([[
        SELECT * FROM rockspecs
        WHERE name = $name AND version = $version AND deleted_at IS NULL
          AND NOT (host = $host AND owner = $owner AND repo = $repo)
        LIMIT 1
    ]], {
        name = candidate.name,
        version = candidate.version,
        host = candidate.host,
        owner = candidate.owner,
        repo = candidate.repo,
    })
end

------------------------------------------------------------------- module M --

local M = {
    DEFAULT_DB_PATH = DEFAULT_DB_PATH,
    now_iso = now_iso,
}

M.DEFAULT_DELETION_GUARD = {
    -- Deletions at or below this absolute count are always allowed.
    floor = 10,
    -- Above the floor, abort when the deletion ratio exceeds this fraction of
    -- the current active registry.
    max_fraction = 0.25,
}

--- Opens (creating if necessary) the rocks.db database and ensures the schema.
--- @param path string|nil
--- @return DB
function M.open(path)
    local db = setmetatable({
        conn = sqlite.open(path or DEFAULT_DB_PATH),
    }, DB)
    db:init_schema()
    return db
end

--- Evaluates whether a batch of deletions is within the safety guard. A run that
--- would remove an unexpectedly large portion of the registry (for example
--- because of a transient API failure that hid repositories) should be aborted
--- and surfaced for manual review rather than applied automatically.
--- @param deletion_count integer
--- @param active_count integer
--- @param options table|nil {floor?, max_fraction?}
--- @return boolean ok, string|nil reason
function M.check_deletion_guard(deletion_count, active_count, options)
    options = options or {}
    local floor = options.floor or M.DEFAULT_DELETION_GUARD.floor
    local max_fraction = options.max_fraction or M.DEFAULT_DELETION_GUARD.max_fraction
    if deletion_count <= floor then
        return true
    end
    if active_count <= 0 then
        return false,
            string.format('refusing to delete %d rockspecs with no active registry state',
                deletion_count)
    end
    local fraction = deletion_count / active_count
    if fraction > max_fraction then
        return false, string.format(
            'deletion of %d/%d rockspecs (%.1f%%) exceeds guard limit of %.1f%%',
            deletion_count, active_count, fraction * 100, max_fraction * 100)
    end
    return true
end

return M

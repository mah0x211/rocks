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
--- Crawler core: discovers rockspec additions, updates, and removals under a
--- crawl source by diffing the live GitHub tree against rocks.db, and records the
--- resulting changes. Deletions are computed up front and gated by the mass
--- deletion guard, and a successful full repository enumeration is required
--- before any deletion is considered, so a transient API failure can never be
--- read as a mass removal.
local db = require('rockup.db')
local rockspec = require('rockup.rockspec')

local function new_report()
    return {
        repos_scanned = 0,
        added = {},
        updated = {},
        deleted = {},
        rejected = {},
        invalid = {},
        failed = {},
    }
end

--- Default validator: accepts every rockspec and attributes provenance to the
--- repository it was discovered in. Replaced by the rockspec validation work
--- item with real linting and tag/provenance checks.
local function accept_all(rec)
    return true, nil, {
        source_host = rec.host,
        source_owner = rec.owner,
        source_repo = rec.repo,
    }
end

--- Determines whether a repository should be deep-scanned on this run.
local function is_candidate(repo, last_crawl_at, ignored, include_forks)
    if ignored then
        return false
    end
    if repo.fork and not include_forks then
        return false
    end
    if not repo.pushed_at then
        return false
    end
    if last_crawl_at == nil then
        return true
    end
    return repo.pushed_at > last_crawl_at
end

--- Builds the per-repository change plan (reads only).
local function plan_repo(conn, gh, host, owner, repo)
    local branch = repo.default_branch or 'master'
    local tree = gh:list_rockspecs(owner, repo.name, branch)

    local tree_by_file = {}
    for _, spec in ipairs(tree) do
        tree_by_file[rockspec.basename(spec.path)] = spec
    end

    local upserts = {}
    for filename, spec in pairs(tree_by_file) do
        local row = conn:get_rockspec(host, owner, repo.name, filename)
        local existing_active = row ~= nil and row.deleted_at == nil
        if not row or row.deleted_at ~= nil or row.blob_sha ~= spec.sha then
            upserts[#upserts + 1] = {
                filename = filename,
                sha = spec.sha,
                was_active = existing_active,
            }
        end
    end

    local deletes = {}
    for _, row in ipairs(conn:list_rockspecs_by_repo(host, owner, repo.name)) do
        -- Only crawl-managed rockspecs are removed when they disappear from the
        -- tree; grandfathered (managed=0) rows are preserved, matching the
        -- reconciliation path.
        if row.managed == 1 and not tree_by_file[row.filename] then
            deletes[#deletes + 1] = row.filename
        end
    end

    return {
        repo = repo,
        branch = branch,
        upserts = upserts,
        deletes = deletes,
    }
end

--- Collects active managed rockspecs whose repository no longer exists under the
--- source, grouped by repository, for reconciliation deletion.
local function reconciliation_deletes(conn, host, owner, existing_names)
    local by_repo = {}
    for _, row in ipairs(conn:list_active_rockspecs()) do
        if row.host == host and row.owner == owner and row.managed == 1 and
            not existing_names[row.repo] then
            by_repo[row.repo] = by_repo[row.repo] or {}
            local list = by_repo[row.repo]
            list[#list + 1] = row.filename
        end
    end
    return by_repo
end

--- Fetches the contents of every changed rockspec in a plan with a single git
--- transfer, keyed by blob SHA.
--- @param gh Github
--- @param owner string
--- @param repo_name string
--- @param upserts table[] items with a `sha` field
--- @return table<string, string> contents keyed by blob SHA
local function fetch_upsert_contents(gh, owner, repo_name, upserts)
    local shas = {}
    for _, item in ipairs(upserts) do
        shas[#shas + 1] = item.sha
    end
    if #shas == 0 then
        return {}
    end
    return gh:fetch_blobs(owner, repo_name, shas)
end

--- Applies a validated rockspec upsert, enforcing provenance collision rejection.
--- The rockspec content is supplied by the caller, which fetches every changed
--- blob of a repository in a single git transfer.
local function apply_upsert(conn, host, owner, repo_name, item, content, validate, report)
    local name, version = rockspec.parse_filename(item.filename)
    local path = repo_name .. '/' .. item.filename
    if not name then
        report.invalid[#report.invalid + 1] = {
            path = path,
            reason = 'unparseable rockspec filename',
        }
        return
    end

    if not content then
        report.invalid[#report.invalid + 1] = {
            path = path,
            reason = 'rockspec content could not be fetched',
        }
        return
    end

    local rec = {
        host = host,
        owner = owner,
        repo = repo_name,
        filename = item.filename,
        name = name,
        version = version,
        blob_sha = item.sha,
        file_size = #content,
        content = content,
        source_host = host,
        source_owner = owner,
        source_repo = repo_name,
    }

    local ok, err, meta = validate(rec)
    if not ok then
        report.invalid[#report.invalid + 1] = {
            path = path,
            reason = err or 'validation failed',
        }
        return
    end
    if meta then
        rec.source_url = meta.source_url or rec.source_url
        rec.source_host = meta.source_host or rec.source_host
        rec.source_owner = meta.source_owner or rec.source_owner
        rec.source_repo = meta.source_repo or rec.source_repo
        if meta.name then
            rec.name = meta.name
        end
        if meta.version then
            rec.version = meta.version
        end
    end

    local conflict = conn:find_conflict({
        name = rec.name,
        version = rec.version,
        host = host,
        owner = owner,
        repo = repo_name,
    })
    if conflict then
        report.rejected[#report.rejected + 1] = {
            path = path,
            reason = string.format('name/version %s %s already published by %s/%s',
                rec.name, rec.version, conflict.owner, conflict.repo),
        }
        return
    end

    conn:upsert_rockspec(rec)
    if item.was_active then
        report.updated[#report.updated + 1] = path
    else
        report.added[#report.added + 1] = path
    end
end

--- Soft-deletes each named rockspec of a repository and records the removals.
local function apply_deletes(conn, host, owner, repo_name, filenames, report)
    for _, filename in ipairs(filenames) do
        conn:soft_delete_rockspec({
            host = host,
            owner = owner,
            repo = repo_name,
            filename = filename,
        })
        report.deleted[#report.deleted + 1] = repo_name .. '/' .. filename
    end
end

--- Fetches and applies every addition/update of a repository.
local function apply_adds(conn, gh, host, owner, repo_name, upserts, validate, report)
    local contents = fetch_upsert_contents(gh, owner, repo_name, upserts)
    for _, item in ipairs(upserts) do
        apply_upsert(conn, host, owner, repo_name, item, contents[item.sha], validate, report)
    end
end

--- The report lists that a repository's processing appends to, captured so a
--- rolled-back repository can be erased from the report as well as the database.
local MUTABLE_SECTIONS = {
    'added',
    'updated',
    'deleted',
    'rejected',
    'invalid',
}

--- Records the current length of each mutable report section.
local function snapshot_report(report)
    local marks = {}
    for _, name in ipairs(MUTABLE_SECTIONS) do
        marks[name] = #report[name]
    end
    return marks
end

--- Truncates each mutable report section back to a recorded length, discarding
--- entries appended by a repository whose transaction was rolled back.
local function restore_report(report, marks)
    for _, name in ipairs(MUTABLE_SECTIONS) do
        local list = report[name]
        for i = #list, marks[name] + 1, -1 do
            list[i] = nil
        end
    end
end

--- Discovers and records rockspec changes for a crawl source.
--- @param conn DB
--- @param source table {host, owner, last_crawl_at?}
--- @param gh Github
--- @param opts table|nil {validate?, guard?, include_forks?}
--- @return table report
local function discover_source(conn, source, gh, opts)
    opts = opts or {}
    local validate = opts.validate or accept_all
    local host = source.host
    local owner = source.owner
    local report = new_report()

    -- Full enumeration must succeed before any deletion is considered.
    local repos = gh:list_repos(owner)
    local existing_names = {}
    for _, repo in ipairs(repos) do
        existing_names[repo.name] = true
    end

    -- Phase 1: build change plans without mutating state.
    local plans = {}
    for _, repo in ipairs(repos) do
        local row = conn:get_repo(host, owner, repo.name)
        local ignored = row ~= nil and row.ignore == 1
        if is_candidate(repo, source.last_crawl_at, ignored, opts.include_forks) then
            plans[#plans + 1] = plan_repo(conn, gh, host, owner, repo)
        end
    end
    local recon = reconciliation_deletes(conn, host, owner, existing_names)

    -- Gate deletions before applying anything.
    local delete_count = 0
    for _, plan in ipairs(plans) do
        delete_count = delete_count + #plan.deletes
    end
    for _, filenames in pairs(recon) do
        delete_count = delete_count + #filenames
    end
    local ok, reason = db.check_deletion_guard(delete_count, conn:count_active_rockspecs(),
        opts.guard)
    if not ok then
        error('deletion guard tripped: ' .. reason)
    end

    -- Reconciliation deletions remove rockspecs of repositories that vanished
    -- from the source entirely; they have no paired addition, so applying them up
    -- front can never strand a replacement.
    for repo_name, filenames in pairs(recon) do
        apply_deletes(conn, host, owner, repo_name, filenames, report)
    end

    -- Each repository is processed in isolation so a transient failure fetching
    -- one repository's blobs or tags records that repository as failed and leaves
    -- the rest of the source to be crawled; the caller keeps the source's crawl
    -- watermark unadvanced so the failed repositories are retried on the next run.
    -- A repository that both removes and adds rockspecs in the same run (a rename
    -- or revision bump) is applied inside a transaction so a failed fetch never
    -- removes a rockspec whose replacement did not land.
    local function upsert_repo(plan)
        conn:upsert_repo({
            host = host,
            owner = owner,
            repo = plan.repo.name,
            default_branch = plan.repo.default_branch,
            pushed_at = plan.repo.pushed_at,
        })
    end

    for _, plan in ipairs(plans) do
        report.repos_scanned = report.repos_scanned + 1
        local has_deletes = #plan.deletes > 0
        local has_adds = #plan.upserts > 0

        if has_deletes and not has_adds then
            -- Deletions only: no addition can fail, so apply directly.
            apply_deletes(conn, host, owner, plan.repo.name, plan.deletes, report)
            upsert_repo(plan)
        elseif has_deletes and has_adds then
            -- Removals and additions together: apply atomically so a failure
            -- rolls back both and the repository is retried intact.
            local marks = snapshot_report(report)
            local pcall_ok, pcall_err = pcall(function()
                conn:transaction(function()
                    apply_deletes(conn, host, owner, plan.repo.name, plan.deletes, report)
                    apply_adds(conn, gh, host, owner, plan.repo.name, plan.upserts, validate,
                        report)
                    upsert_repo(plan)
                end)
            end)
            if not pcall_ok then
                restore_report(report, marks)
                report.failed[#report.failed + 1] = {
                    repo = plan.repo.name,
                    reason = tostring(pcall_err),
                }
            end
        else
            -- Additions only: isolate so one repository's fetch failure does not
            -- abort the rest. No deletion can be stranded here.
            local pcall_ok, pcall_err = pcall(function()
                apply_adds(conn, gh, host, owner, plan.repo.name, plan.upserts, validate, report)
                upsert_repo(plan)
            end)
            if not pcall_ok then
                report.failed[#report.failed + 1] = {
                    repo = plan.repo.name,
                    reason = tostring(pcall_err),
                }
            end
        end
    end

    return report
end

--- Discovers and records rockspec changes for a single repository, bypassing the
--- date gate and reconciliation. Used for one-off and un-ignore operations.
--- @param conn DB
--- @param target table {host, owner, repo}
--- @param gh Github
--- @param opts table|nil {validate?, default_branch?}
--- @return table report
local function discover_repo(conn, target, gh, opts)
    opts = opts or {}
    local validate = opts.validate or accept_all
    local host = target.host
    local owner = target.owner
    local report = new_report()

    local branch = opts.default_branch
    if not branch then
        branch = gh:default_branch(owner, target.repo)
    end
    local repo = {
        name = target.repo,
        default_branch = branch,
    }
    local plan = plan_repo(conn, gh, host, owner, repo)

    report.repos_scanned = 1
    -- Additions run before deletions so a failed fetch aborts before any rockspec
    -- is removed, never stranding a single-repository rename.
    apply_adds(conn, gh, host, owner, target.repo, plan.upserts, validate, report)
    apply_deletes(conn, host, owner, target.repo, plan.deletes, report)

    return report
end

return {
    discover_source = discover_source,
    discover_repo = discover_repo,
}

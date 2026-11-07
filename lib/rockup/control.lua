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
--- Manual control operations invoked out of band from the periodic crawl:
--- excluding or re-including repositories, pausing and resuming updates, scanning
--- a single repository once, and managing crawl sources. These run regardless of
--- the keep-alive schedule; the caller materializes and publishes afterwards.
local crawler = require('rockup.crawler')

local DEFAULT_HOST = 'github.com'

--- Parses an "owner/repo" string (optionally "host/owner/repo") into a target.
--- @param str string
--- @return table|nil {host, owner, repo}
local function parse_target(str)
    local parts = {}
    for part in (str .. '/'):gmatch('(.-)/') do
        if part ~= '' then
            parts[#parts + 1] = part
        end
    end
    if #parts == 2 then
        return {
            host = DEFAULT_HOST,
            owner = parts[1],
            repo = parts[2],
        }
    elseif #parts == 3 then
        return {
            host = parts[1],
            owner = parts[2],
            repo = parts[3],
        }
    end
    return nil
end

--- Pauses periodic updates. Scheduled runs become no-ops until resumed.
--- @param conn DB
local function pause(conn)
    conn:set_paused(true)
end

--- Resumes periodic updates.
--- @param conn DB
local function resume(conn)
    conn:set_paused(false)
end

--- Sets the ignore flag on repositories. Excluding a repository soft-deletes its
--- rockspecs so they stop being served; re-including it immediately scans the
--- repository to bring its rockspecs back.
--- @param conn DB
--- @param gh Github
--- @param targets table[] array of {host, owner, repo}
--- @param ignore boolean
--- @param opts table|nil {validate?}
--- @return table report
local function set_ignore(conn, gh, targets, ignore, opts)
    opts = opts or {}
    local report = {
        ignored = {},
        unignored = {},
        added = {},
        updated = {},
        deleted = {},
        invalid = {},
        rejected = {},
    }

    for _, t in ipairs(targets) do
        conn:upsert_repo({
            host = t.host,
            owner = t.owner,
            repo = t.repo,
        })
        conn:set_repo_ignore({
            host = t.host,
            owner = t.owner,
            repo = t.repo,
            ignore = ignore,
        })

        local label = t.owner .. '/' .. t.repo
        if ignore then
            for _, row in ipairs(conn:list_rockspecs_by_repo(t.host, t.owner, t.repo)) do
                conn:soft_delete_rockspec({
                    host = t.host,
                    owner = t.owner,
                    repo = t.repo,
                    filename = row.filename,
                })
                report.deleted[#report.deleted + 1] = t.repo .. '/' .. row.filename
            end
            report.ignored[#report.ignored + 1] = label
        else
            conn:revive_grandfathered(t.host, t.owner, t.repo)
            local sub = crawler.discover_repo(conn, t, gh, {
                validate = opts.validate,
            })
            for _, v in ipairs(sub.added) do
                report.added[#report.added + 1] = v
            end
            for _, v in ipairs(sub.updated) do
                report.updated[#report.updated + 1] = v
            end
            for _, v in ipairs(sub.deleted) do
                report.deleted[#report.deleted + 1] = v
            end
            for _, v in ipairs(sub.invalid) do
                report.invalid[#report.invalid + 1] = v
            end
            for _, v in ipairs(sub.rejected) do
                report.rejected[#report.rejected + 1] = v
            end
            report.unignored[#report.unignored + 1] = label
        end
    end

    return report
end

--- Scans a single repository once and records its rockspecs without adding it to
--- the periodic crawl sources (it is not crawled again automatically).
--- @param conn DB
--- @param gh Github
--- @param target table {host, owner, repo}
--- @param opts table|nil {validate?}
--- @return table report
local function scan_once(conn, gh, target, opts)
    opts = opts or {}
    return crawler.discover_repo(conn, target, gh, {
        validate = opts.validate,
    })
end

--- Adds or updates a crawl source.
--- @param conn DB
--- @param source table {host, owner, api_base?, enabled?}
local function add_source(conn, source)
    conn:upsert_source(source)
end

--- Enables or disables a crawl source.
--- @param conn DB
--- @param host string
--- @param owner string
--- @param enabled boolean
local function set_source_enabled(conn, host, owner, enabled)
    conn:set_source_enabled(host, owner, enabled)
end

return {
    parse_target = parse_target,
    pause = pause,
    resume = resume,
    set_ignore = set_ignore,
    scan_once = scan_once,
    add_source = add_source,
    set_source_enabled = set_source_enabled,
}

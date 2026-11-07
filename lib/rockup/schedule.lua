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
--- Keep-alive scheduling for crawl sources. GitHub Actions can only schedule a
--- fixed cron, so each run decides at execution time whether a source is due. A
--- source that keeps producing no changes is crawled progressively less often
--- (exponential backoff up to a cap); any change resets it to the base interval.
--- Comparisons use ISO-8601 UTC timestamps, which order lexicographically, so a
--- delayed or skipped cron tick never causes an early crawl.
local db = require('rockup.db')
local crawler = require('rockup.crawler')

local HOUR = 3600
local BASE_INTERVAL_SEC = 6 * HOUR
local MAX_INTERVAL_SEC = 48 * HOUR

--- Backoff interval (seconds) for a given step, capped at the maximum.
--- @param backoff_step integer
--- @return integer
local function interval_for(backoff_step)
    local seconds = BASE_INTERVAL_SEC * (2 ^ (backoff_step or 0))
    if seconds > MAX_INTERVAL_SEC then
        return MAX_INTERVAL_SEC
    end
    return seconds
end

--- Highest backoff step whose interval is still within the cap. Computed from the
--- uncapped interval so the search terminates.
local MAX_STEP = 0
while BASE_INTERVAL_SEC * (2 ^ (MAX_STEP + 1)) <= MAX_INTERVAL_SEC do
    MAX_STEP = MAX_STEP + 1
end

--- Decides whether a source should be crawled now.
--- A forced run always proceeds; otherwise the global pause flag and the
--- source's next-due time gate the run.
--- @param conn DB
--- @param source table {next_crawl_due?}
--- @param opts table|nil {force?, now_iso?}
--- @return boolean run, string|nil reason
local function should_run(conn, source, opts)
    opts = opts or {}
    if opts.force then
        return true
    end
    if conn:is_paused() then
        return false, 'paused'
    end
    local now_iso = opts.now_iso or db.now_iso()
    if source.next_crawl_due and now_iso < source.next_crawl_due then
        return false, 'not due'
    end
    return true
end

--- Computes the next scheduling state after a crawl completes.
--- @param changed boolean whether the crawl produced any change
--- @param backoff_step integer current backoff step
--- @param opts table|nil {now_epoch?}
--- @return table {backoff_step, next_crawl_due, last_crawl_at}
local function next_state(changed, backoff_step, opts)
    opts = opts or {}
    local now_epoch = opts.now_epoch or os.time()
    local step
    if changed then
        step = 0
    else
        step = math.min((backoff_step or 0) + 1, MAX_STEP)
    end
    return {
        backoff_step = step,
        next_crawl_due = os.date('!%Y-%m-%dT%H:%M:%SZ', now_epoch + interval_for(step)),
        last_crawl_at = os.date('!%Y-%m-%dT%H:%M:%SZ', now_epoch),
    }
end

--- Crawls a source if it is due, then advances its keep-alive schedule. When the
--- run is gated (paused or not due) nothing is crawled and the source state is
--- left untouched, so no commit is produced.
--- @param conn DB
--- @param source table {host, owner, next_crawl_due?, backoff_step?}
--- @param gh Github
--- @param opts table|nil {validate?, guard?, force?, now_iso?, now_epoch?}
--- @return table {skipped, reason?, changed?, report?}
local function run_source(conn, source, gh, opts)
    opts = opts or {}
    local run, reason = should_run(conn, source, opts)
    if not run then
        return {
            skipped = true,
            reason = reason,
        }
    end

    local report = crawler.discover_source(conn, source, gh, {
        validate = opts.validate,
        guard = opts.guard,
        include_forks = opts.include_forks,
    })
    local changed = #report.added + #report.updated + #report.deleted > 0
    local incomplete = #report.failed > 0

    local state
    if incomplete then
        -- A repository failed to crawl (for example a transient git error). Keep
        -- the crawl watermark where it is so the failed repositories stay crawl
        -- candidates, and schedule a prompt retry instead of backing off.
        local now_epoch = opts.now_epoch or os.time()
        state = {
            backoff_step = 0,
            next_crawl_due = os.date('!%Y-%m-%dT%H:%M:%SZ', now_epoch + interval_for(0)),
            last_crawl_at = source.last_crawl_at,
        }
    else
        state = next_state(changed, source.backoff_step, opts)
    end
    conn:update_source_crawl_state({
        host = source.host,
        owner = source.owner,
        last_crawl_at = state.last_crawl_at,
        next_crawl_due = state.next_crawl_due,
        backoff_step = state.backoff_step,
    })

    return {
        skipped = false,
        changed = changed,
        report = report,
    }
end

return {
    BASE_INTERVAL_SEC = BASE_INTERVAL_SEC,
    MAX_INTERVAL_SEC = MAX_INTERVAL_SEC,
    MAX_STEP = MAX_STEP,
    interval_for = interval_for,
    should_run = should_run,
    next_state = next_state,
    run_source = run_source,
}

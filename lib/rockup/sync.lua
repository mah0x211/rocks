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
--- Orchestrates a full registry sync: crawl every enabled source under the
--- keep-alive schedule, then rebuild the served directory from rocks.db. Git
--- commit/push is left to the workflow that arranges the master and gh-pages
--- working trees; this module only mutates rocks.db and the served files.
local schedule = require('rockup.schedule')
local registry = require('rockup.registry')
local rockspec = require('rockup.rockspec')
local sh = require('rockup.sh')

--- Crawls every enabled source, respecting the per-source keep-alive gate. A
--- failure crawling one source (for example a transient GitHub error) is captured
--- and reported, so the remaining sources are still processed.
--- @param conn DB
--- @param gh Github
--- @param opts table|nil {validate?, force?, guard?, now_iso?, now_epoch?}
--- @return table {sources = {...}, changed = boolean}
local function run_all(conn, gh, opts)
    opts = opts or {}
    local results = {}
    local changed = false
    for _, source in ipairs(conn:list_enabled_sources()) do
        local ok, result = pcall(schedule.run_source, conn, source, gh, {
            validate = opts.validate,
            force = opts.force,
            guard = opts.guard,
            include_forks = opts.include_forks,
            now_iso = opts.now_iso,
            now_epoch = opts.now_epoch,
        })
        if not ok then
            result = {
                error = tostring(result),
            }
        end
        results[#results + 1] = {
            host = source.host,
            owner = source.owner,
            result = result,
        }
        if ok and not result.skipped and result.changed then
            changed = true
        end
    end
    return {
        sources = results,
        changed = changed,
    }
end

--- Rebuilds the served directory and manifests from rocks.db.
--- @param conn DB
--- @param serve_dir string
--- @return table materialize result
local function publish(conn, serve_dir)
    local result = registry.materialize(conn, serve_dir)
    registry.regenerate_manifest(serve_dir)
    return result
end

--- Lists rockspec basenames in a directory.
local function rockspec_files(dir)
    local code, out = sh.exec({
        'find',
        dir,
        '-maxdepth',
        '1',
        '-name',
        '*.rockspec',
        '-printf',
        '%f\n',
    })
    local names = {}
    if code == 0 then
        for name in (out .. '\n'):gmatch('(.-)\n') do
            if name ~= '' then
                names[#names + 1] = name
            end
        end
    end
    return names
end

--- Imports the rockspecs already published in a served directory into rocks.db as
--- grandfathered (managed=false) rows, so the first crawl does not delete them.
--- Provenance is taken from each rockspec's source URL when it is a GitHub URL, so
--- a later crawl of that repository takes the row over (managed becomes true)
--- instead of being rejected as a name collision.
--- @param conn DB
--- @param serve_dir string
--- @return integer imported
local function seed_existing(conn, serve_dir)
    local imported = 0
    for _, filename in ipairs(rockspec_files(serve_dir)) do
        local name, version = rockspec.parse_filename(filename)
        if name then
            local fh = io.open(serve_dir .. '/' .. filename, 'rb')
            local content = fh and fh:read('*a') or ''
            if fh then
                fh:close()
            end
            local spec = rockspec.load(content) or {}
            local source = spec.source or {}
            local host, owner, repo = rockspec.parse_source_url(source.url)
            conn:upsert_rockspec({
                host = host or 'github.com',
                owner = owner or 'unknown',
                repo = repo or name,
                filename = filename,
                name = name,
                version = version,
                content = content,
                file_size = #content,
                managed = false,
                source_url = source.url,
                source_host = host,
                source_owner = owner,
                source_repo = repo,
            })
            imported = imported + 1
        end
    end
    return imported
end

return {
    run_all = run_all,
    publish = publish,
    seed_existing = seed_existing,
}

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
--- Renders operation results as a Markdown job summary for GitHub Actions.
local concat = table.concat

local function counts(report)
    return string.format('+%d ~%d -%d (rejected %d, invalid %d, failed %d)', #report.added,
        #report.updated, #report.deleted, #report.rejected, #report.invalid,
        report.failed and #report.failed or 0)
end

--- Formats the result of a full sync run.
--- @param aggregate table from sync.run_all
--- @return string markdown
local function format_sync(aggregate)
    local lines = {
        '## rockup sync',
    }
    for _, entry in ipairs(aggregate.sources) do
        local r = entry.result
        local label = entry.owner
        if r.error then
            lines[#lines + 1] = string.format('- `%s`: failed (%s)', label, r.error)
        elseif r.skipped then
            lines[#lines + 1] = string.format('- `%s`: skipped (%s)', label, r.reason or 'n/a')
        else
            lines[#lines + 1] = string.format('- `%s`: %d repos scanned, %s', label,
                r.report.repos_scanned, counts(r.report))
            if r.report.failed and #r.report.failed > 0 then
                local failures = {}
                for _, f in ipairs(r.report.failed) do
                    failures[#failures + 1] = f.repo .. ' (' .. f.reason .. ')'
                end
                lines[#lines + 1] = string.format('    - failed repos: %s',
                    concat(failures, '; '))
            end
            local function detail(name, items)
                if items and #items > 0 then
                    local parts = {}
                    for _, x in ipairs(items) do
                        parts[#parts + 1] = x.path .. ' (' .. x.reason .. ')'
                    end
                    lines[#lines + 1] = string.format('    - %s: %s', name,
                        concat(parts, '; '))
                end
            end
            detail('rejected', r.report.rejected)
            detail('invalid', r.report.invalid)
        end
    end
    if not aggregate.changed then
        lines[#lines + 1] = ''
        lines[#lines + 1] = 'No changes; registry not republished.'
    end
    return concat(lines, '\n') .. '\n'
end

--- Formats a control operation report (ignore / unignore / scan).
--- @param title string
--- @param report table
--- @return string markdown
local function format_control(title, report)
    local lines = {
        '## ' .. title,
    }
    local function section(name, items)
        if items and #items > 0 then
            lines[#lines + 1] = string.format('- %s (%d): %s', name, #items,
                concat(items, ', '))
        end
    end
    section('ignored', report.ignored)
    section('re-included', report.unignored)
    section('added', report.added)
    section('updated', report.updated)
    section('removed', report.deleted)
    if report.rejected and #report.rejected > 0 then
        local reasons = {}
        for _, r in ipairs(report.rejected) do
            reasons[#reasons + 1] = r.path .. ' (' .. r.reason .. ')'
        end
        lines[#lines + 1] = string.format('- rejected (%d): %s', #report.rejected,
            concat(reasons, '; '))
    end
    if report.invalid and #report.invalid > 0 then
        local reasons = {}
        for _, r in ipairs(report.invalid) do
            reasons[#reasons + 1] = r.path .. ' (' .. r.reason .. ')'
        end
        lines[#lines + 1] = string.format('- invalid (%d): %s', #report.invalid,
            concat(reasons, '; '))
    end
    return concat(lines, '\n') .. '\n'
end

--- Formats the current exclusion and source state.
--- @param ignored table[] repos rows
--- @param sources table[] sources rows
--- @return string markdown
local function format_state(ignored, sources)
    local lines = {
        '## registry state',
        string.format('- excluded repositories: %d', #ignored),
    }
    for _, repo in ipairs(ignored) do
        lines[#lines + 1] = string.format('  - `%s/%s`', repo.owner, repo.repo)
    end
    lines[#lines + 1] = string.format('- crawl sources: %d', #sources)
    for _, source in ipairs(sources) do
        lines[#lines + 1] = string.format('  - `%s/%s` (%s)', source.host, source.owner,
            source.enabled == 1 and 'enabled' or 'disabled')
    end
    return concat(lines, '\n') .. '\n'
end

return {
    format_sync = format_sync,
    format_control = format_control,
    format_state = format_state,
}

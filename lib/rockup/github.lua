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
--- GitHub access layer. Repository and tree metadata are read over the REST API
--- via the `gh api` runner, while rockspec contents and tags are retrieved over
--- the git protocol (see rockup.gitrepo) so they do not draw on the REST rate
--- limit. Both the REST runner (`api`) and the git client (`git`) are injectable
--- so discovery logic can be exercised without invoking gh or git.
local gh = require('rockup.gh')
local gitrepo = require('rockup.gitrepo')

--- The only host this client targets; the REST runner and git URLs are rooted at
--- github.com.
local HOST = 'github.com'

--- @class Github
local Github = {}
Github.__index = Github

--- Creates a GitHub client.
--- @param opts table|nil {api?, git?} REST runner and git client
--- @return Github
local function new(opts)
    opts = opts or {}
    return setmetatable({
        api = opts.api or gh.api,
        git = opts.git or gitrepo.new(),
    }, Github)
end

--- Splits runner output into non-empty lines.
local function to_lines(out)
    local lines = {}
    for line in ((out or '') .. '\n'):gmatch('(.-)\n') do
        if line ~= '' then
            lines[#lines + 1] = line
        end
    end
    return lines
end

--- Splits a tab-separated line into fields.
local function split_tsv(line)
    local fields = {}
    for field in (line .. '\t'):gmatch('(.-)\t') do
        fields[#fields + 1] = field
    end
    return fields
end

--- Lists public repositories of an owner, newest pushed first.
--- @param owner string
--- @return table[] array of {name, default_branch, pushed_at, fork}
function Github:list_repos(owner)
    local path = string.format('users/%s/repos?sort=pushed&per_page=100', owner)
    local code, out = self.api(path, {
        paginate = true,
        jq = '.[] | [.name, (.default_branch // ""), (.pushed_at // ""), (.fork | tostring)] | @tsv',
    })
    if code ~= 0 then
        error(string.format('list_repos(%s) failed: %s', owner, out))
    end

    local repos = {}
    for _, line in ipairs(to_lines(out)) do
        local f = split_tsv(line)
        repos[#repos + 1] = {
            name = f[1],
            default_branch = f[2] ~= '' and f[2] or nil,
            pushed_at = f[3] ~= '' and f[3] or nil,
            fork = f[4] == 'true',
        }
    end
    return repos
end

--- Lists rockspec blobs in a repository's tree at the given ref.
--- @param owner string
--- @param repo string
--- @param ref string branch or commit to read the tree from
--- @return table[] array of {path, sha}
function Github:list_rockspecs(owner, repo, ref)
    local path = string.format('repos/%s/%s/git/trees/%s?recursive=1', owner, repo, ref)
    local code, out = self.api(path, {
        jq = '"truncated:\\(.truncated)", ' ..
            '(.tree[] | select(.type == "blob" and (.path | endswith(".rockspec"))) | [.path, .sha] | @tsv)',
    })
    if code ~= 0 then
        -- An empty repository (no commits) or a missing ref has no rockspecs.
        if out:find('HTTP 404', 1, true) or out:find('HTTP 409', 1, true) then
            return {}
        end
        error(string.format('list_rockspecs(%s/%s@%s) failed: %s', owner, repo, ref, out))
    end

    local specs = {}
    for _, line in ipairs(to_lines(out)) do
        local truncated = line:match('^truncated:(%a+)$')
        if truncated then
            -- A truncated tree would hide rockspecs that could later be read as
            -- deletions, so refuse to proceed instead of under-reporting.
            if truncated == 'true' then
                error(string.format('tree for %s/%s@%s is truncated', owner, repo, ref))
            end
        else
            local f = split_tsv(line)
            specs[#specs + 1] = {
                path = f[1],
                sha = f[2],
            }
        end
    end
    return specs
end

--- Fetches the raw bytes of the given blob SHAs over the git protocol, keyed by
--- SHA. This does not use the REST API, so it does not consume the REST rate
--- limit. Returns an empty table when no SHAs are given.
--- @param owner string
--- @param repo string
--- @param shas string[]
--- @return table<string, string> contents keyed by blob SHA
function Github:fetch_blobs(owner, repo, shas)
    return self.git:fetch_blobs(HOST, owner, repo, shas)
end

--- Returns the default branch of a repository.
--- @param owner string
--- @param repo string
--- @return string
function Github:default_branch(owner, repo)
    local path = string.format('repos/%s/%s', owner, repo)
    local code, out = self.api(path, {
        jq = '.default_branch',
    })
    if code ~= 0 then
        error(string.format('default_branch(%s/%s) failed: %s', owner, repo, out))
    end
    local branch = out:gsub('%s+$', '')
    if branch == '' then
        error(string.format('default_branch(%s/%s) returned no branch', owner, repo))
    end
    return branch
end

--- Lists the tags of a repository as a set of tag names, retrieved over the git
--- protocol (not the REST API).
--- @param owner string
--- @param repo string
--- @return table<string, boolean> set of tag names
function Github:list_tags(owner, repo)
    return self.git:list_tags(HOST, owner, repo)
end

return {
    new = new,
}

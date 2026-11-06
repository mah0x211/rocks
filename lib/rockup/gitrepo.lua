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
--- Git-transport access to repositories. Rockspec contents are fetched by their
--- blob object SHA and tags are listed over the git protocol, so neither draws on
--- the REST API rate limit. Blobs are fetched directly by OID into a throwaway
--- repository without downloading trees or history, so the cost is independent of
--- the repository's size or where the rockspec lives in its tree. The command
--- runner is injectable so the logic can be exercised without invoking git.
local sh = require('rockup.sh')

--- @class GitRepo
local GitRepo = {}
GitRepo.__index = GitRepo

--- Creates a git-transport client.
--- @param opts table|nil {exec?, read?} command runners, defaulting to sh
--- @return GitRepo
local function new(opts)
    opts = opts or {}
    return setmetatable({
        exec = opts.exec or sh.exec,
        read = opts.read or sh.read,
    }, GitRepo)
end

--- Builds the https clone URL for a repository.
local function clone_url(host, owner, repo)
    return string.format('https://%s/%s/%s.git', host, owner, repo)
end

--- Fetches the raw bytes of the given blob object SHAs from a repository, keyed
--- by SHA. All blobs are retrieved in a single fetch into a temporary repository,
--- then read out byte-for-byte. Returns an empty table when no SHAs are given.
--- @param host string
--- @param owner string
--- @param repo string
--- @param shas string[]
--- @return table<string, string> contents keyed by blob SHA
function GitRepo:fetch_blobs(host, owner, repo, shas)
    local result = {}
    if not shas or #shas == 0 then
        return result
    end

    local url = clone_url(host, owner, repo)
    local code, dir = self.exec({
        'mktemp',
        '-d',
    })
    dir = (dir or ''):gsub('%s+$', '')
    if code ~= 0 or dir == '' then
        error('mktemp failed: ' .. (dir or ''))
    end

    local ok, err = pcall(function()
        local c, out = self.exec({
            'git',
            '-C',
            dir,
            'init',
            '-q',
        })
        if c ~= 0 then
            error('git init failed: ' .. out)
        end

        local fetch = {
            'git',
            '-C',
            dir,
            'fetch',
            '-q',
            '--no-tags',
            url,
        }
        for _, sha in ipairs(shas) do
            fetch[#fetch + 1] = sha
        end
        c, out = self.exec(fetch)
        if c ~= 0 then
            error(string.format('git fetch %s failed: %s', url, out))
        end

        for _, sha in ipairs(shas) do
            local sc, size = self.exec({
                'git',
                '-C',
                dir,
                'cat-file',
                '-s',
                sha,
            })
            if sc ~= 0 then
                error(string.format('cat-file -s %s failed: %s', sha, size))
            end
            local want = tonumber((size:gsub('%s+$', '')))
            local content = self.read({
                'git',
                '-C',
                dir,
                'cat-file',
                'blob',
                sha,
            })
            if want and #content ~= want then
                error(string.format('blob %s size mismatch: got %d want %d',
                    sha, #content, want))
            end
            result[sha] = content
        end
    end)

    self.exec({
        'rm',
        '-rf',
        dir,
    })
    if not ok then
        error(err)
    end
    return result
end

--- Lists the tags of a repository as a set of tag names. Peeled annotated-tag
--- references (ending in "^{}") are folded into their tag name, so both
--- lightweight and annotated tags are reported by name.
--- @param host string
--- @param owner string
--- @param repo string
--- @return table<string, boolean> set of tag names
function GitRepo:list_tags(host, owner, repo)
    local url = clone_url(host, owner, repo)
    local code, out = self.exec({
        'git',
        'ls-remote',
        '--tags',
        url,
    })
    if code ~= 0 then
        error(string.format('git ls-remote --tags %s failed: %s', url, out))
    end

    local tags = {}
    for line in ((out or '') .. '\n'):gmatch('(.-)\n') do
        local ref = line:match('\trefs/tags/(.+)$')
        if ref then
            ref = ref:gsub('%^{}$', '')
            tags[ref] = true
        end
    end
    return tags
end

return {
    new = new,
}

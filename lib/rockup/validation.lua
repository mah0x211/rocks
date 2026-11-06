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
--- Rockspec validation used to gate what enters the registry. A rockspec must
--- lint cleanly, its declared package and version must match its filename, and if
--- it pins a source.tag that tag must exist in the repository the source URL
--- points at. Tag existence is checked against the repository's full tag set,
--- fetched once per repository over the git protocol and memoized for the run, so
--- it does not issue a REST request per rockspec. The build is never run (no
--- `luarocks make`), so a rockspec is never rejected merely because a heavy C
--- dependency fails to build in the runner.
local sh = require('rockup.sh')
local rockspec = require('rockup.rockspec')

--- Default linter: writes the rockspec to a correctly named temporary file (the
--- name LuaRocks requires) and runs `luarocks lint`.
--- @param filename string
--- @param content string
--- @return boolean ok, string|nil err
local function default_lint(filename, content)
    local dir = os.tmpname()
    os.remove(dir)
    sh.exec({
        'mkdir',
        '-p',
        dir,
    })
    local path = dir .. '/' .. filename
    local fh, open_err = io.open(path, 'wb')
    if not fh then
        sh.exec({
            'rm',
            '-rf',
            dir,
        })
        return false, open_err
    end
    fh:write(content)
    fh:close()

    local code, out = sh.exec({
        'luarocks',
        'lint',
        path,
    })
    sh.exec({
        'rm',
        '-rf',
        dir,
    })
    if code ~= 0 then
        return false, out
    end
    return true
end

--- @class Validator
local Validator = {}
Validator.__index = Validator

--- Returns the tag-name set of a repository, fetching it once per repository and
--- memoizing the result for the lifetime of the validator.
--- @param self Validator
--- @param owner string
--- @param repo string
--- @return table<string, boolean>
local function tag_set(self, owner, repo)
    local key = owner .. '/' .. repo
    local cached = self.tag_cache[key]
    if cached == nil then
        cached = self.github:list_tags(owner, repo)
        self.tag_cache[key] = cached
    end
    return cached
end

--- Validates a discovered rockspec record.
--- @param self Validator
--- @param rec table {filename, name, version, content, host, owner, repo}
--- @return boolean ok, string|nil err, table|nil meta
local function validate(self, rec)
    local ok, err = self.lint(rec.filename, rec.content)
    if not ok then
        return false, 'luarocks lint failed: ' .. (err or '')
    end

    local spec, load_err = rockspec.load(rec.content)
    if not spec then
        return false, 'could not read rockspec: ' .. (load_err or '')
    end

    if spec.package ~= rec.name then
        return false, string.format('package %s does not match filename name %s',
            tostring(spec.package), rec.name)
    end
    if spec.version ~= rec.version then
        return false, string.format('version %s does not match filename version %s',
            tostring(spec.version), rec.version)
    end

    local source = spec.source or {}
    local host, owner, repo = rockspec.parse_source_url(source.url)
    local meta = {
        source_url = source.url,
        source_host = host or rec.host,
        source_owner = owner or rec.owner,
        source_repo = repo or rec.repo,
    }

    if source.tag then
        if not host then
            return false, string.format('cannot verify source.tag %s for non-GitHub source %s',
                source.tag, tostring(source.url))
        end
        if not tag_set(self, owner, repo)[source.tag] then
            return false, string.format('source.tag %s not found in %s/%s', source.tag, owner, repo)
        end
    end

    return true, nil, meta
end

--- Creates a validator and returns it as a `validate(rec)` function suitable for
--- injection into the crawler.
--- @param opts table {github, lint?}
--- @return function validate
local function new(opts)
    local self = setmetatable({
        github = opts.github,
        lint = opts.lint or default_lint,
        tag_cache = {},
    }, Validator)
    return function(rec)
        return validate(self, rec)
    end
end

return {
    new = new,
    default_lint = default_lint,
}

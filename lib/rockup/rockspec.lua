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
--- Helpers for working with rockspec files. Validation of rockspec contents is
--- added by a later work item; this module currently covers path and filename
--- handling shared by the crawler.

--- Returns the final path segment of a slash-separated path.
--- @param path string
--- @return string
local function basename(path)
    return (path:gsub('.*/', ''))
end

--- Parses a rockspec filename into its package name and full version (version
--- and revision) using the LuaRocks `<name>-<version>-<revision>.rockspec`
--- convention. The package name may itself contain hyphens.
--- @param filename string
--- @return string|nil name, string|nil version
local function parse_filename(filename)
    return filename:match('^(.*)%-([^%-]+%-%d+)%.rockspec$')
end

--- Loads rockspec contents in an empty sandbox environment and returns the table
--- of fields it assigns (package, version, source, ...). The sandbox exposes no
--- globals, so a rockspec that attempts to call into os/io or any other library
--- raises instead of executing, and such a rockspec is treated as invalid.
--- @param content string
--- @return table|nil spec, string|nil err
local function load(content)
    local chunk, err = loadstring(content, 'rockspec')
    if not chunk then
        return nil, err
    end
    local env = {}
    setfenv(chunk, env)
    local ok, run_err = pcall(chunk)
    if not ok then
        return nil, run_err
    end
    return env
end

--- Extracts the host, owner, and repository from a GitHub source URL such as
--- `git+https://github.com/owner/repo.git`. Returns nil for non-GitHub URLs.
--- @param url string|nil
--- @return string|nil host, string|nil owner, string|nil repo
local function parse_source_url(url)
    if type(url) ~= 'string' then
        return nil
    end
    local owner, repo = url:match('github%.com[/:]([^/]+)/([^/#?]+)')
    if not owner then
        return nil
    end
    repo = repo:gsub('%.git$', '')
    return 'github.com', owner, repo
end

return {
    basename = basename,
    parse_filename = parse_filename,
    load = load,
    parse_source_url = parse_source_url,
}

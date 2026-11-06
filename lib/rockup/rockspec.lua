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

return {
    basename = basename,
    parse_filename = parse_filename,
}

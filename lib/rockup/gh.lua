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
--- Runner for the `gh` CLI. `gh api` provides authentication (via GITHUB_TOKEN),
--- Link-header pagination, custom media types, and built-in jq filtering, so the
--- tooling needs no Lua HTTP or JSON dependency.
local concat = table.concat

--- Shell-quotes a single argument for safe interpolation into a command string.
--- @param s string
--- @return string
local function shquote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

--- Executes a command (given as an argument vector) and captures its combined
--- output and exit status. Output and exit code are recovered together via a
--- trailing marker so a single pipe suffices under LuaJIT's io.popen semantics.
--- @param argv string[]
--- @return integer code, string output
local function exec(argv)
    local quoted = {}
    for i, arg in ipairs(argv) do
        quoted[i] = shquote(arg)
    end
    local cmd = concat(quoted, ' ') .. ' 2>&1; printf "\\n__RC__%d__" "$?"'
    local handle = assert(io.popen(cmd, 'r'))
    local out = handle:read('*a') or ''
    handle:close()

    local body, code = out:match('^(.*)\n__RC__(%d+)__%s*$')
    if not code then
        return 1, out
    end
    return tonumber(code), body
end

--- Invokes `gh api` for the given path.
--- @param path string API path with optional query string
--- @param opts table|nil {paginate?, jq?, silent?, headers? = {"Name: value"}}
--- @param runner function|nil exec implementation (for testing)
--- @return integer code, string output
local function api(path, opts, runner)
    opts = opts or {}
    runner = runner or exec
    local argv = {
        'gh',
        'api',
        path,
    }
    if opts.paginate then
        argv[#argv + 1] = '--paginate'
    end
    if opts.silent then
        argv[#argv + 1] = '--silent'
    end
    if opts.headers then
        for _, header in ipairs(opts.headers) do
            argv[#argv + 1] = '-H'
            argv[#argv + 1] = header
        end
    end
    if opts.jq then
        argv[#argv + 1] = '--jq'
        argv[#argv + 1] = opts.jq
    end
    return runner(argv)
end

return {
    exec = exec,
    api = api,
    shquote = shquote,
}

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
--- Minimal helpers for running external commands and capturing their combined
--- output and exit status.
local concat = table.concat

--- Shell-quotes a single argument for safe interpolation into a command string.
--- @param s string
--- @return string
local function shquote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

--- Executes a command (given as an argument vector) and captures its combined
--- output and exit status. The exit code is recovered alongside the output via a
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

--- Executes a command and returns its raw stdout bytes verbatim, discarding
--- stderr and the exit status. Unlike `exec`, no marker is appended, so binary
--- content (including a trailing newline) is preserved exactly. The caller is
--- responsible for confirming success separately (for example by checking an
--- expected size), since the exit code is not recovered here.
--- @param argv string[]
--- @return string output
local function read(argv)
    local quoted = {}
    for i, arg in ipairs(argv) do
        quoted[i] = shquote(arg)
    end
    local cmd = concat(quoted, ' ') .. ' 2>/dev/null'
    local handle = assert(io.popen(cmd, 'r'))
    local out = handle:read('*a') or ''
    handle:close()
    return out
end

return {
    exec = exec,
    read = read,
    shquote = shquote,
}

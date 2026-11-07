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
--- Materializes the registry that LuaRocks serves. rocks.db is the source of
--- truth; the served directory is rebuilt to contain exactly the active
--- rockspecs as flat `<name>-<version>-<revision>.rockspec` files (the layout the
--- LuaRocks client expects), after which the LuaRocks manifests are regenerated.
local sh = require('rockup.sh')

--- Lists the basenames of rockspec files in a directory.
--- @param dir string
--- @return string[]
local function existing_rockspecs(dir)
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
    if code ~= 0 then
        return {}
    end
    local names = {}
    for name in (out .. '\n'):gmatch('(.-)\n') do
        if name ~= '' then
            names[#names + 1] = name
        end
    end
    return names
end

--- Rebuilds the served directory from the active rockspecs in rocks.db. Active
--- rockspecs are written as flat files and any rockspec file that is no longer
--- active is removed, so deletions and name changes leave no orphans.
--- @param conn DB
--- @param dir string served directory (e.g. the gh-pages working tree)
--- @return table {written = string[], removed = string[]}
local function materialize(conn, dir)
    local want = {}
    local written = {}
    for _, row in ipairs(conn:list_active_rockspecs()) do
        if row.content ~= nil then
            want[row.filename] = true
            local path = dir .. '/' .. row.filename
            local fh = assert(io.open(path, 'wb'))
            fh:write(row.content)
            fh:close()
            written[#written + 1] = row.filename
        end
    end

    local removed = {}
    for _, name in ipairs(existing_rockspecs(dir)) do
        if not want[name] then
            os.remove(dir .. '/' .. name)
            removed[#removed + 1] = name
        end
    end

    return {
        written = written,
        removed = removed,
    }
end

--- Regenerates the LuaRocks manifests for the served directory and refreshes the
--- per-version manifest zip archives the LuaRocks client downloads.
--- @param dir string
local function regenerate_manifest(dir)
    local code, out = sh.exec({
        'luarocks-admin',
        'make_manifest',
        dir,
    })
    if code ~= 0 then
        error('make_manifest failed: ' .. out)
    end

    -- Produce deterministic zips: identical manifest content yields byte-identical
    -- archives (fixed mtime via touch, no extra attributes via -X), so a no-op
    -- republish does not create a spurious commit.
    local zip_cmd = 'cd ' .. sh.shquote(dir) .. [[ && for m in manifest-5.*; do
        case "$m" in *.zip) continue ;; esac
        [ -f "$m" ] || continue
        touch -d @0 "$m"
        rm -f "$m.zip"
        zip -qX "$m.zip" "$m"
    done]]
    local zcode, zout = sh.exec({
        'sh',
        '-c',
        zip_cmd,
    })
    if zcode ~= 0 then
        error('manifest zip failed: ' .. zout)
    end
end

return {
    materialize = materialize,
    regenerate_manifest = regenerate_manifest,
}

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
--- Minimal LuaJIT FFI binding to libsqlite3.
---
--- This wrapper intentionally exposes only the small surface the registry tooling
--- needs (open/close, prepared statements, named-parameter binding of
--- text/integer/float/blob/null, row iteration and transactions). Keeping the
--- binding small and explicit limits the amount of hand-written low-level code in
--- a supply-chain sensitive tool.
local ffi = require('ffi')

ffi.cdef [[
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;
typedef void (*sqlite3_destructor_type)(void*);

int sqlite3_open(const char *filename, sqlite3 **ppDb);
int sqlite3_close_v2(sqlite3 *db);
int sqlite3_exec(sqlite3 *db, const char *sql, void *cb, void *arg, char **errmsg);
const char *sqlite3_errmsg(sqlite3 *db);
int sqlite3_extended_result_codes(sqlite3 *db, int onoff);

int sqlite3_prepare_v2(sqlite3 *db, const char *zSql, int nByte,
                       sqlite3_stmt **ppStmt, const char **pzTail);
int sqlite3_finalize(sqlite3_stmt *stmt);
int sqlite3_reset(sqlite3_stmt *stmt);
int sqlite3_step(sqlite3_stmt *stmt);

int sqlite3_bind_parameter_count(sqlite3_stmt *stmt);
const char *sqlite3_bind_parameter_name(sqlite3_stmt *stmt, int i);
int sqlite3_bind_text(sqlite3_stmt *stmt, int i, const char *v, int n, sqlite3_destructor_type);
int sqlite3_bind_blob(sqlite3_stmt *stmt, int i, const void *v, int n, sqlite3_destructor_type);
int sqlite3_bind_int64(sqlite3_stmt *stmt, int i, int64_t v);
int sqlite3_bind_double(sqlite3_stmt *stmt, int i, double v);
int sqlite3_bind_null(sqlite3_stmt *stmt, int i);

int sqlite3_column_count(sqlite3_stmt *stmt);
const char *sqlite3_column_name(sqlite3_stmt *stmt, int i);
int sqlite3_column_type(sqlite3_stmt *stmt, int i);
const unsigned char *sqlite3_column_text(sqlite3_stmt *stmt, int i);
const void *sqlite3_column_blob(sqlite3_stmt *stmt, int i);
int sqlite3_column_bytes(sqlite3_stmt *stmt, int i);
int64_t sqlite3_column_int64(sqlite3_stmt *stmt, int i);
double sqlite3_column_double(sqlite3_stmt *stmt, int i);

int sqlite3_changes(sqlite3 *db);
int64_t sqlite3_last_insert_rowid(sqlite3 *db);
]]

local C = ffi.load('sqlite3')

local SQLITE_OK = 0
local SQLITE_ROW = 100
local SQLITE_DONE = 101

local SQLITE_INTEGER = 1
local SQLITE_FLOAT = 2
local SQLITE_TEXT = 3
local SQLITE_BLOB = 4
-- local SQLITE_NULL = 5

-- SQLITE_TRANSIENT instructs SQLite to copy the bound buffer, so the Lua string
-- backing it does not need to outlive the bind call.
local SQLITE_TRANSIENT = ffi.cast('sqlite3_destructor_type', ffi.cast('intptr_t', -1))

--- Marks a Lua string so it is bound as a BLOB rather than TEXT.
--- @param s string
--- @return table
local function blob(s)
    return setmetatable({
        data = s,
    }, {
        __index = {
            is_blob = true,
        },
    })
end

local function is_blob(v)
    return type(v) == 'table' and getmetatable(v) and getmetatable(v).__index and
               getmetatable(v).__index.is_blob == true
end

--- @class Statement
local Statement = {}
Statement.__index = Statement

local function bind_one(stmt_ptr, idx, value)
    if value == nil then
        return C.sqlite3_bind_null(stmt_ptr, idx)
    elseif is_blob(value) then
        local s = value.data
        return C.sqlite3_bind_blob(stmt_ptr, idx, s, #s, SQLITE_TRANSIENT)
    elseif type(value) == 'string' then
        return C.sqlite3_bind_text(stmt_ptr, idx, value, #value, SQLITE_TRANSIENT)
    elseif type(value) == 'boolean' then
        return C.sqlite3_bind_int64(stmt_ptr, idx, value and 1 or 0)
    elseif type(value) == 'number' then
        if value == math.floor(value) and math.abs(value) < 2 ^ 63 then
            return C.sqlite3_bind_int64(stmt_ptr, idx, value)
        end
        return C.sqlite3_bind_double(stmt_ptr, idx, value)
    end
    error('unsupported bind value type: ' .. type(value))
end

--- Binds a parameter table to the statement.
--- Supports named parameters ($name/:name/@name keyed without the prefix) and
--- positional parameters (array indices).
--- @param params table|nil
function Statement:bind(params)
    params = params or {}
    local stmt = self._stmt
    local n = C.sqlite3_bind_parameter_count(stmt)
    for i = 1, n do
        local pname = C.sqlite3_bind_parameter_name(stmt, i)
        local value
        if pname ~= nil then
            local key = ffi.string(pname):sub(2)
            value = params[key]
        else
            value = params[i]
        end
        if bind_one(stmt, i, value) ~= SQLITE_OK then
            error(self._conn:errmsg())
        end
    end
end

local function column_value(stmt, i)
    local t = C.sqlite3_column_type(stmt, i)
    if t == SQLITE_INTEGER then
        return tonumber(C.sqlite3_column_int64(stmt, i))
    elseif t == SQLITE_FLOAT then
        return C.sqlite3_column_double(stmt, i)
    elseif t == SQLITE_TEXT then
        local n = C.sqlite3_column_bytes(stmt, i)
        return ffi.string(C.sqlite3_column_text(stmt, i), n)
    elseif t == SQLITE_BLOB then
        local n = C.sqlite3_column_bytes(stmt, i)
        return ffi.string(C.sqlite3_column_blob(stmt, i), n)
    end
    return nil
end

--- Advances the statement one step.
--- @return string 'row' when a row is available, 'done' when finished.
function Statement:step()
    local rc = C.sqlite3_step(self._stmt)
    if rc == SQLITE_ROW then
        return 'row'
    elseif rc == SQLITE_DONE then
        return 'done'
    end
    error(self._conn:errmsg())
end

--- Returns the current row as a map of column name to value.
--- @return table
function Statement:row()
    local stmt = self._stmt
    local n = C.sqlite3_column_count(stmt)
    local row = {}
    for i = 0, n - 1 do
        local name = ffi.string(C.sqlite3_column_name(stmt, i))
        row[name] = column_value(stmt, i)
    end
    return row
end

--- Finalizes (releases) the statement.
function Statement:finalize()
    if self._stmt ~= nil then
        C.sqlite3_finalize(self._stmt)
        self._stmt = nil
    end
end

--- @class Connection
local Connection = {}
Connection.__index = Connection

--- Returns the most recent error message from the connection.
--- @return string
function Connection:errmsg()
    return ffi.string(C.sqlite3_errmsg(self._db))
end

--- Prepares a SQL statement.
--- @param sql string
--- @return Statement
function Connection:prepare(sql)
    local pp = ffi.new('sqlite3_stmt*[1]')
    if C.sqlite3_prepare_v2(self._db, sql, #sql, pp, nil) ~= SQLITE_OK then
        error(self:errmsg() .. ' (while preparing: ' .. sql .. ')')
    end
    return setmetatable({
        _stmt = pp[0],
        _conn = self,
    }, Statement)
end

--- Executes one or more SQL statements with no result rows.
--- @param sql string
function Connection:exec(sql)
    local errp = ffi.new('char*[1]')
    if C.sqlite3_exec(self._db, sql, nil, nil, errp) ~= SQLITE_OK then
        local msg = errp[0] ~= nil and ffi.string(errp[0]) or self:errmsg()
        error(msg)
    end
end

--- Runs a statement to completion, returning affected row metadata.
--- @param sql string
--- @param params table|nil
--- @return table {changes = integer, last_insert_rowid = integer}
function Connection:run(sql, params)
    local stmt = self:prepare(sql)
    local ok, err = pcall(function()
        stmt:bind(params)
        while stmt:step() == 'row' do
            -- drain any rows the statement might produce
        end
    end)
    stmt:finalize()
    if not ok then
        error(err)
    end
    return {
        changes = C.sqlite3_changes(self._db),
        last_insert_rowid = tonumber(C.sqlite3_last_insert_rowid(self._db)),
    }
end

--- Returns the first row of a query, or nil.
--- @param sql string
--- @param params table|nil
--- @return table|nil
function Connection:get(sql, params)
    local stmt = self:prepare(sql)
    local result
    local ok, err = pcall(function()
        stmt:bind(params)
        if stmt:step() == 'row' then
            result = stmt:row()
        end
    end)
    stmt:finalize()
    if not ok then
        error(err)
    end
    return result
end

--- Returns all rows of a query as an array.
--- @param sql string
--- @param params table|nil
--- @return table[]
function Connection:all(sql, params)
    local stmt = self:prepare(sql)
    local rows = {}
    local ok, err = pcall(function()
        stmt:bind(params)
        while stmt:step() == 'row' do
            rows[#rows + 1] = stmt:row()
        end
    end)
    stmt:finalize()
    if not ok then
        error(err)
    end
    return rows
end

--- Runs fn within a transaction, rolling back on error.
--- @param fn function
--- @return any
function Connection:transaction(fn)
    self:exec('BEGIN')
    local ok, result = pcall(fn)
    if ok then
        self:exec('COMMIT')
        return result
    end
    pcall(function()
        self:exec('ROLLBACK')
    end)
    error(result)
end

--- Closes the connection.
function Connection:close()
    if self._db ~= nil then
        C.sqlite3_close_v2(self._db)
        self._db = nil
    end
end

--- Opens (creating if necessary) a SQLite database.
--- @param path string
--- @return Connection
local function open(path)
    local pp = ffi.new('sqlite3*[1]')
    if C.sqlite3_open(path, pp) ~= SQLITE_OK then
        local db = pp[0]
        local msg = db ~= nil and ffi.string(C.sqlite3_errmsg(db)) or 'failed to open database'
        if db ~= nil then
            C.sqlite3_close_v2(db)
        end
        error(msg)
    end
    local conn = setmetatable({
        _db = pp[0],
    }, Connection)
    C.sqlite3_extended_result_codes(conn._db, 1)
    return conn
end

return {
    open = open,
    blob = blob,
}

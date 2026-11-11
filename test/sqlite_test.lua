require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local sqlite = require('rockup.sqlite')

function testcase.exec_and_run_report_changes()
    local db = sqlite.open(':memory:')
    db:exec('CREATE TABLE t(a TEXT, n INTEGER, b BLOB)')
    local r = db:run('INSERT INTO t(a, n) VALUES($a, $n)', {
        a = 'hi',
        n = 42,
    })
    assert.equal(r.changes, 1)
    assert.equal(r.last_insert_rowid, 1)
    db:close()
end

function testcase.get_and_all_with_named_params()
    local db = sqlite.open(':memory:')
    db:exec('CREATE TABLE t(a TEXT, n INTEGER)')
    db:run('INSERT INTO t(a, n) VALUES($a, $n)', {
        a = 'x',
        n = 1,
    })
    db:run('INSERT INTO t(a, n) VALUES($a, $n)', {
        a = 'y',
        n = 2,
    })

    local row = db:get('SELECT a, n FROM t WHERE a = $a', {
        a = 'y',
    })
    assert.equal(row.a, 'y')
    assert.equal(row.n, 2)

    local rows = db:all('SELECT a FROM t ORDER BY a')
    assert.equal(#rows, 2)
    assert.equal(rows[1].a, 'x')
    db:close()
end

function testcase.get_returns_nil_when_no_row()
    local db = sqlite.open(':memory:')
    db:exec('CREATE TABLE t(a TEXT)')
    assert.is_nil(db:get('SELECT a FROM t'))
    db:close()
end

function testcase.positional_parameters()
    local db = sqlite.open(':memory:')
    db:exec('CREATE TABLE t(a TEXT, n INTEGER)')
    db:run('INSERT INTO t(a, n) VALUES(?, ?)', {
        'z',
        9,
    })
    local row = db:get('SELECT a, n FROM t')
    assert.equal(row.a, 'z')
    assert.equal(row.n, 9)
    db:close()
end

function testcase.blob_roundtrip_preserves_nul_bytes()
    local db = sqlite.open(':memory:')
    db:exec('CREATE TABLE t(b BLOB)')
    local payload = 'bin\0data\255'
    db:run('INSERT INTO t(b) VALUES($b)', {
        b = sqlite.blob(payload),
    })
    local row = db:get('SELECT b FROM t')
    assert.equal(row.b, payload)
    db:close()
end

function testcase.null_binding_and_float()
    local db = sqlite.open(':memory:')
    db:exec('CREATE TABLE t(a TEXT, f REAL)')
    db:run('INSERT INTO t(a, f) VALUES($a, $f)', {
        a = nil,
        f = 1.5,
    })
    local row = db:get('SELECT a, f FROM t')
    assert.is_nil(row.a)
    assert.equal(row.f, 1.5)
    db:close()
end

function testcase.transaction_commits_on_success()
    local db = sqlite.open(':memory:')
    db:exec('CREATE TABLE t(a TEXT)')
    db:transaction(function()
        db:run('INSERT INTO t(a) VALUES($a)', {
            a = 'ok',
        })
    end)
    assert.equal(db:get('SELECT COUNT(*) AS c FROM t').c, 1)
    db:close()
end

function testcase.transaction_rolls_back_on_error()
    local db = sqlite.open(':memory:')
    db:exec('CREATE TABLE t(a TEXT)')
    local err = assert.throws(function()
        db:transaction(function()
            db:run('INSERT INTO t(a) VALUES($a)', {
                a = 'x',
            })
            error('boom')
        end)
    end)
    assert.match(err, 'boom')
    assert.equal(db:get('SELECT COUNT(*) AS c FROM t').c, 0)
    db:close()
end

function testcase.invalid_sql_raises()
    local db = sqlite.open(':memory:')
    assert.throws(function()
        db:prepare('SELECT * FROM does_not_exist')
    end)
    db:close()
end

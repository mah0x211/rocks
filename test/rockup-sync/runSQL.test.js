import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

import { runSQL } from '../../scripts/rockup-sync-gh-pages.mjs';

const withTempDir = (fn) => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rocks-sql-'));
    const previousCwd = process.cwd();
    process.chdir(tmpDir);
    try {
        fn(tmpDir);
    } finally {
        process.chdir(previousCwd);
        fs.rmSync(tmpDir, { recursive: true, force: true });
    }
};

describe('runSQL()', () => {
    test('opens rocks.db and executes statements without parameters', () => {
        withTempDir(() => {
            assert.ok(!fs.existsSync('rocks.db'));

            runSQL('CREATE TABLE demo (id INTEGER PRIMARY KEY)');

            assert.ok(fs.existsSync('rocks.db'));
            const db = new DatabaseSync('rocks.db');
            try {
                const tables = db.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all();
                assert.deepStrictEqual(tables.map((row) => row.name), ['demo']);
            } finally {
                db.close();
            }
        });
    });

    test('executes prepared statements with parameters', () => {
        withTempDir(() => {
            runSQL('CREATE TABLE demo (value TEXT)');
            runSQL('INSERT INTO demo (value) VALUES ($value)', { value: 'foo' });

            const db = new DatabaseSync('rocks.db');
            try {
                const rows = db.prepare('SELECT value FROM demo').all();
                assert.deepStrictEqual(rows.map((row) => row.value), ['foo']);
            } finally {
                db.close();
            }
        });
    });

    test('rolls back the transaction when execution fails', () => {
        withTempDir(() => {
            runSQL('CREATE TABLE demo (value TEXT UNIQUE)');
            runSQL('INSERT INTO demo (value) VALUES ($value)', { value: 'foo' });

            assert.throws(() => {
                runSQL('INSERT INTO demo (value) VALUES ($value)', { value: 'foo' });
            }, (error) => {
                const message = String(error?.message ?? error);
                assert.match(message, /(SQLITE_CONSTRAINT|UNIQUE)/);
                return true;
            });

            const db = new DatabaseSync('rocks.db');
            try {
                const rows = db.prepare('SELECT value FROM demo').all();
                assert.deepStrictEqual(rows.map((row) => row.value), ['foo']);
            } finally {
                db.close();
            }
        });
    });
});

import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

import { createRocksDbIfNotExists } from '../../scripts/rockup-sync-gh-pages.mjs';

const withTempDir = (fn) => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rocks-test-'));
    const previousCwd = process.cwd();
    process.chdir(tmpDir);
    try {
        fn(tmpDir);
    } finally {
        process.chdir(previousCwd);
        fs.rmSync(tmpDir, { recursive: true, force: true });
    }
};

const openDb = () => new DatabaseSync('rocks.db');

describe('Test createRocksDbIfNotExists()', () => {
    test('creates database when missing', () => {
        withTempDir(() => {
            assert.ok(!fs.existsSync('rocks.db'));
            createRocksDbIfNotExists();
            assert.ok(fs.existsSync('rocks.db'));

            const db = openDb();
            try {
                const tables = db
                    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'rockspecs'")
                    .all();
                assert.strictEqual(tables.length, 1);
            } finally {
                db.close();
            }
        });
    });

    test('leaves existing database untouched', () => {
        withTempDir(() => {
            const db = openDb();
            db.exec('CREATE TABLE sentinel (id INTEGER PRIMARY KEY)');
            db.close();

            createRocksDbIfNotExists();

            const reopened = openDb();
            try {
                const tableNames = reopened
                    .prepare("SELECT name FROM sqlite_master WHERE type = 'table'")
                    .all()
                    .map((row) => row.name);
                assert.ok(tableNames.includes('sentinel'));
                assert.ok(!tableNames.includes('rockspecs'));
            } finally {
                reopened.close();
            }
        });
    });

    test('creates rockspecs table with expected schema', () => {
        withTempDir(() => {
            createRocksDbIfNotExists();

            const db = openDb();
            try {
                const columns = db.prepare('PRAGMA table_info(rockspecs)').all();
                const columnNames = columns.map((col) => col.name);
                assert.deepStrictEqual(columnNames, [
                    'id',
                    'host',
                    'owner',
                    'repo',
                    'filename',
                    'name',
                    'version',
                    'commit_sha',
                    'file_size',
                    'content',
                    'created_at',
                    'updated_at'
                ]);

                const primaryKey = columns.find((col) => col.pk === 1);
                assert(primaryKey, 'primary key is missing');
                assert.strictEqual(primaryKey.name, 'id');
            } finally {
                db.close();
            }
        });
    });

    test('fails when directory lacks write permissions', () => {
        withTempDir((dir) => {
            const protectedDir = path.join(dir, 'protected');
            fs.mkdirSync(protectedDir, { mode: 0o555 });

            const previousCwd = process.cwd();
            process.chdir(protectedDir);
            try {
                assert.throws(() => {
                    createRocksDbIfNotExists();
                }, (error) => {
                    const message = String(error?.message ?? error);
                    assert.match(message, /(SQLITE|permission|unable to open database)/i);
                    return true;
                });
            } finally {
                process.chdir(previousCwd);
                fs.chmodSync(protectedDir, 0o755);
            }
        });
    });

    test('keeps corrupted database file untouched', () => {
        withTempDir(() => {
            const corruptContent = Buffer.from('not a sqlite database', 'utf8');
            fs.writeFileSync('rocks.db', corruptContent);

            createRocksDbIfNotExists();

            const after = fs.readFileSync('rocks.db');
            assert.deepStrictEqual(after, corruptContent);
        });
    });

    test('creates supporting index for unique constraint', () => {
        withTempDir(() => {
            createRocksDbIfNotExists();

            const db = openDb();
            try {
                const indexes = db.prepare("PRAGMA index_list('rockspecs')").all();
                assert.ok(indexes.length > 0, 'expected at least one index');

                const hasUnique = indexes
                    .filter((idx) => idx.unique === 1)
                    .some((idx) => String(idx.name).includes('sqlite_autoindex_rockspecs'));
                assert.ok(hasUnique, 'missing auto index for unique constraint');
            } finally {
                db.close();
            }
        });
    });

    test('is idempotent on repeated calls', () => {
        withTempDir(() => {
            createRocksDbIfNotExists();
            createRocksDbIfNotExists();

            const db = openDb();
            try {
                const tables = db
                    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'rockspecs'")
                    .all();
                assert.strictEqual(tables.length, 1);
            } finally {
                db.close();
            }
        });
    });
});

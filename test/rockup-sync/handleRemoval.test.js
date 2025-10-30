import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

import {
    handleRemoval,
    createRocksDbIfNotExists
} from '../../scripts/rockup-sync-gh-pages.mjs';

const ROCKSPEC_PATH = 'rockspecs/github.com/example-owner/example-repo/example-1.2.3-1.rockspec';

const withTempDir = (fn) => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rocks-handle-removal-'));
    const previousCwd = process.cwd();
    process.chdir(tmpDir);
    try {
        createRocksDbIfNotExists();
        fn(tmpDir);
    } finally {
        process.chdir(previousCwd);
        fs.rmSync(tmpDir, { recursive: true, force: true });
    }
};

const insertRecord = (overrides = {}) => {
    const db = new DatabaseSync('rocks.db');
    try {
        const defaults = {
            host: 'github.com',
            owner: 'example-owner',
            repo: 'example-repo',
            filename: 'example-1.2.3-1.rockspec',
            name: 'example',
            version: '1.2.3-1',
            commit_sha: 'deadbeef',
            file_size: 0,
            content: Buffer.from('dummy'),
            created_at: '2024-01-01T00:00:00.000Z',
            updated_at: '2024-01-01T00:00:00.000Z'
        };
        const record = { ...defaults, ...overrides };
        const stmt = db.prepare(`
            INSERT INTO rockspecs (
                host, owner, repo, filename, name, version, commit_sha,
                file_size, content, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `);
        stmt.run(
            record.host,
            record.owner,
            record.repo,
            record.filename,
            record.name,
            record.version,
            record.commit_sha,
            record.file_size,
            record.content,
            record.created_at,
            record.updated_at
        );
        return record;
    } finally {
        db.close();
    }
};

const fetchRecord = (filename) => {
    const db = new DatabaseSync('rocks.db');
    try {
        return db.prepare(`
            SELECT created_at, updated_at
            FROM rockspecs
            WHERE filename = ?
        `).get(filename);
    } finally {
        db.close();
    }
};

describe('handleRemoval()', () => {
    test('deletes matching rockspec rows', () => {
        withTempDir(() => {
            const initial = insertRecord();

            handleRemoval(ROCKSPEC_PATH);

            const row = fetchRecord(initial.filename);
            assert.equal(row, undefined);
        });
    });

    test('ignores non-matching rockspec paths', () => {
        withTempDir(() => {
            const initial = insertRecord({ filename: 'other-1.0.0-1.rockspec' });

            handleRemoval(ROCKSPEC_PATH);

            const row = fetchRecord(initial.filename);
            assert.ok(row);
            assert.equal(row.updated_at, initial.updated_at);
        });
    });

    test('rejects invalid rockspec paths', () => {
        withTempDir(() => {
            insertRecord();
            assert.throws(
                () => handleRemoval('invalid/path/example-1.2.3-1.rockspec'),
                /Invalid rockspec path/
            );
        });
    });
});


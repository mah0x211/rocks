import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

import {
    handleAddOrUpdate,
    createRocksDbIfNotExists
} from '../../scripts/rockup-sync-gh-pages.mjs';

const ROCKSPEC_PATH = 'rockspecs/github.com/example-owner/example-repo/example-1.2.3-1.rockspec';

const withTempDir = (fn) => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rocks-handle-add-'));
    const previousCwd = process.cwd();
    process.chdir(tmpDir);
    const restorePath = installLuarocksStub(tmpDir);
    try {
        createRocksDbIfNotExists();
        fn(tmpDir);
    } finally {
        restorePath();
        process.chdir(previousCwd);
        fs.rmSync(tmpDir, { recursive: true, force: true });
    }
};

const installLuarocksStub = (dir) => {
    const binDir = path.join(dir, 'bin');
    fs.mkdirSync(binDir, { recursive: true });
    const stubPath = path.join(binDir, process.platform === 'win32' ? 'luarocks.bat' : 'luarocks');
    const script = process.platform === 'win32'
        ? '@echo off\nEXIT /B 0\n'
        : '#!/bin/sh\nexit 0\n';
    fs.writeFileSync(stubPath, script, { mode: process.platform === 'win32' ? 0o666 : 0o755 });
    if (process.platform !== 'win32') {
        fs.chmodSync(stubPath, 0o755);
    }
    const previousPath = process.env.PATH ?? '';
    process.env.PATH = `${binDir}${path.delimiter}${previousPath}`;
    return () => {
        process.env.PATH = previousPath;
    };
};

const ensureRockspecFile = (filePath, { name, version, body = '' }) => {
    const dir = path.dirname(filePath);
    fs.mkdirSync(dir, { recursive: true });
    const content = `package = "${name}"\nversion = "${version}"\n${body}`;
    fs.writeFileSync(filePath, content);
    return content;
};

const readRow = (filename) => {
    const db = new DatabaseSync('rocks.db');
    try {
        return db.prepare(`
            SELECT host, owner, repo, filename, name, version, commit_sha,
                   file_size, content, created_at, updated_at
            FROM rockspecs
            WHERE filename = ?
        `).get(filename);
    } finally {
        db.close();
    }
};

const countRows = () => {
    const db = new DatabaseSync('rocks.db');
    try {
        return db.prepare('SELECT COUNT(*) AS count FROM rockspecs').get().count;
    } finally {
        db.close();
    }
};

describe('handleAddOrUpdate()', () => {
    test('inserts a new rockspec record with expected metadata', () => {
        withTempDir(() => {
            const content = ensureRockspecFile(ROCKSPEC_PATH, {
                name: 'example',
                version: '1.2.3-1'
            });

            const committedAt = '2024-03-01T00:00:00.000Z';

            handleAddOrUpdate(ROCKSPEC_PATH, 'deadbeef', committedAt);

            const row = readRow('example-1.2.3-1.rockspec');
            assert.ok(row);
            assert.equal(row.host, 'github.com');
            assert.equal(row.owner, 'example-owner');
            assert.equal(row.repo, 'example-repo');
            assert.equal(row.name, 'example');
            assert.equal(row.version, '1.2.3-1');
            assert.equal(row.commit_sha, 'deadbeef');
            assert.equal(row.file_size, Buffer.byteLength(content));
            assert.deepEqual(Buffer.from(row.content), Buffer.from(content));
            assert.equal(row.created_at, committedAt);
            assert.equal(row.updated_at, committedAt);
        });
    });

    test('updates existing record in place and preserves created_at', () => {
        withTempDir(() => {
            ensureRockspecFile(ROCKSPEC_PATH, {
                name: 'example',
                version: '1.2.3-1'
            });
            const firstCommitAt = '2024-03-01T00:00:00.000Z';
            handleAddOrUpdate(ROCKSPEC_PATH, 'deadbeef', firstCommitAt);

            // override created_at to simulate older record
            const db = new DatabaseSync('rocks.db');
            try {
                db.exec(`UPDATE rockspecs SET created_at = '2000-01-01T00:00:00.000Z'`);
            } finally {
                db.close();
            }

            const updatedContent = ensureRockspecFile(ROCKSPEC_PATH, {
                name: 'example',
                version: '1.2.3-1',
                body: 'description = "updated"\n'
            });

            const secondCommitAt = '2024-04-15T00:00:00.000Z';
            handleAddOrUpdate(ROCKSPEC_PATH, 'feedbead', secondCommitAt);

            assert.equal(countRows(), 1);
            const row = readRow('example-1.2.3-1.rockspec');
            assert.ok(row);
            assert.equal(row.version, '1.2.3-1');
            assert.equal(row.commit_sha, 'feedbead');
            assert.equal(row.created_at, '2000-01-01T00:00:00.000Z');
            assert.equal(row.file_size, Buffer.byteLength(updatedContent));
            assert.deepEqual(Buffer.from(row.content), Buffer.from(updatedContent));
            assert.equal(row.updated_at, secondCommitAt);
        });
    });

    test('throws when rockspec path does not match expected format', () => {
        withTempDir(() => {
            assert.throws(
                () => handleAddOrUpdate('invalid/path/example.rockspec', 'deadbeef', '2024-03-01T00:00:00.000Z'),
                /Invalid rockspec path/
            );
        });
    });

    test('throws when rockspec file is missing or invalid', () => {
        withTempDir(() => {
            assert.throws(
                () => handleAddOrUpdate(ROCKSPEC_PATH, 'deadbeef', '2024-03-01T00:00:00.000Z'),
                /ENOENT/
            );
        });
    });
});

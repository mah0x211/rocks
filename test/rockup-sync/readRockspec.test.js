import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { readRockspec } from '../../scripts/rockup-sync-gh-pages.mjs';

const withTempDir = (fn) => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rocks-read-'));
    const previousCwd = process.cwd();
    process.chdir(tmpDir);
    try {
        fn(tmpDir);
    } finally {
        process.chdir(previousCwd);
        fs.rmSync(tmpDir, { recursive: true, force: true });
    }
};

const installLuarocksStub = (dir, { exitCode = 0, stderr = '', stdout = '', script } = {}) => {
    const binDir = path.join(dir, 'bin');
    fs.mkdirSync(binDir, { recursive: true });
    const stubPath = path.join(binDir, 'luarocks');

    const content = script ?? `#!/bin/bash\n\nif [ "$1" = "lint" ]; then\n  exit ${exitCode}\nelse\n  echo "unexpected command: $@" >&2\n  exit 1\nfi\n`;

    fs.writeFileSync(stubPath, content, { mode: 0o755 });
    fs.chmodSync(stubPath, 0o755);

    const previousPath = process.env.PATH ?? '';
    process.env.PATH = `${binDir}${path.delimiter}${previousPath}`;

    return () => {
        process.env.PATH = previousPath;
    };
};

describe('Test readRockspec()', () => {
    test('returns rockspec metadata for valid file', () => {
        withTempDir((dir) => {
            const restorePath = installLuarocksStub(dir);
            try {
                const fileName = 'my-package-1.2.3-1.rockspec';
                const content = 'package = "my-package"\nversion = "1.2.3-1"\n';
                fs.writeFileSync(fileName, content);

                const result = readRockspec(fileName);

                assert.strictEqual(result.fileSize, Buffer.byteLength(content));
                assert.strictEqual(result.name, 'my-package');
                assert.strictEqual(result.version, '1.2.3-1');
                assert.ok(Buffer.isBuffer(result.buffer));
                assert.strictEqual(result.buffer.toString('utf8'), content);
            } finally {
                restorePath();
            }
        });
    });

    test('throws when luarocks lint reports an error', () => {
        withTempDir((dir) => {
            const restorePath = installLuarocksStub(dir, {
                script: `#!/bin/bash\n\nif [ "$1" = "lint" ]; then\n  echo "lint failure" >&2\n  exit 1\nfi\nexit 1\n`
            });
            try {
                const fileName = 'broken-0.1.0-1.rockspec';
                fs.writeFileSync(fileName, 'invalid content');

                assert.throws(() => {
                    readRockspec(fileName);
                }, (error) => {
                    const message = String(error?.message ?? error);
                    assert.match(message, /Invalid rockspec file broken-0.1.0-1\.rockspec: luarocks exited with code 1/i);
                    assert.match(message, /lint failure/i);
                    return true;
                });
            } finally {
                restorePath();
            }
        });
    });

    test('rejects filenames that do not follow LuaRocks convention', () => {
        withTempDir((dir) => {
            const restorePath = installLuarocksStub(dir);
            try {
                const invalidName = 'mypkg-1.0.0.rockspec';
                fs.writeFileSync(invalidName, 'package = "mypkg"\n');

                assert.throws(() => {
                    readRockspec(invalidName);
                }, /Invalid rockspec filename format: mypkg-1\.0\.0\.rockspec/);
            } finally {
                restorePath();
            }
        });
    });

    test('propagates filesystem errors when file cannot be read', () => {
        withTempDir((dir) => {
            const restorePath = installLuarocksStub(dir);
            try {
                const missing = 'missing-1.0.0-1.rockspec';

                assert.throws(() => {
                    readRockspec(missing);
                }, (error) => {
                    const message = String(error?.message ?? error);
                    assert.match(message, /ENOENT/);
                    assert.match(message, /missing-1\.0\.0-1\.rockspec/);
                    return true;
                });
            } finally {
                restorePath();
            }
        });
    });
});

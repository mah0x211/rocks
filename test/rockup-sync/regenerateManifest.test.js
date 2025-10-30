import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

import { regenerateManifest } from '../../scripts/rockup-sync-gh-pages.mjs';

const LUA_VERSIONS = ['5.1', '5.2', '5.3', '5.4'];

const withTempDir = (fn) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rocks-manifest-'));
    const previousCwd = process.cwd();
    process.chdir(dir);
    try {
        fn(dir);
    } finally {
        process.chdir(previousCwd);
        fs.rmSync(dir, { recursive: true, force: true });
    }
};

const createSampleRockspec = () => {
    const rockspecDir = path.join('rockspecs', 'example');
    fs.mkdirSync(rockspecDir, { recursive: true });
    fs.writeFileSync(
        path.join(rockspecDir, 'sample-1.0-1.rockspec'),
        `package = "sample"
version = "1.0-1"
source = { url = "git://example/sample", tag = "v1.0" }
description = { summary = "sample" }
build = { type = "builtin", modules = {} }
`
    );
};

const prependPath = (dir) => {
    const originalPath = process.env.PATH || '';
    process.env.PATH = `${dir}${path.delimiter}${originalPath}`;
    return originalPath;
};

describe('regenerateManifest()', () => {
    test('creates manifest and zip files when commands succeed', () => {
        withTempDir(() => {
            createSampleRockspec();

            assert.doesNotThrow(() => regenerateManifest());

            assert.ok(fs.existsSync('manifest'));
            for (const ver of LUA_VERSIONS) {
                const manifestPath = `manifest-${ver}`;
                const zipPath = `${manifestPath}.zip`;
                assert.ok(fs.existsSync(manifestPath), `${manifestPath} should be created`);
                assert.ok(fs.existsSync(zipPath), `${zipPath} should be created`);
            }
        });
    });

    test('throws when luarocks-admin fails', () => {
        withTempDir((dir) => {
            const binDir = path.join(dir, 'fail-bin');
            fs.mkdirSync(binDir);
            const stubPath = path.join(binDir, 'luarocks-admin');
            fs.writeFileSync(stubPath, '#!/bin/sh\nexit 1\n', { mode: 0o755 });

            const originalPath = prependPath(binDir);
            try {
                createSampleRockspec();
                assert.throws(() => regenerateManifest());
            } finally {
                process.env.PATH = originalPath;
            }
        });
    });

    test('throws when zip command fails', () => {
        withTempDir((dir) => {
            createSampleRockspec();

            const binDir = path.join(dir, 'fail-zip-bin');
            fs.mkdirSync(binDir);
            const stubZip = path.join(binDir, 'zip');
            fs.writeFileSync(stubZip, '#!/bin/sh\nexit 1\n', { mode: 0o755 });

            const originalPath = prependPath(binDir);

            try {
                assert.throws(() => regenerateManifest(), /Failed to create manifest-5.1.zip/);
            } finally {
                process.env.PATH = originalPath;
            }
        });
    });
});

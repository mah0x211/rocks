import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

import { getGitChanges } from '../../scripts/rockup-sync-gh-pages.mjs';

const withGitRepo = (fn) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rocks-diff-'));
    const previous = process.cwd();
    process.chdir(dir);
    try {
        runGit(['init']);
        runGit(['config', 'user.name', 'Test User']);
        runGit(['config', 'user.email', 'test@example.com']);
        fn(dir);
    } finally {
        process.chdir(previous);
        fs.rmSync(dir, { recursive: true, force: true });
    }
};

const runGit = (args) => {
    const result = spawnSync('git', args, { encoding: 'utf8' });
    if (result.status !== 0) {
        throw new Error(result.stderr || `git ${args.join(' ')} failed`);
    }
    return result.stdout.trim();
};

const writeFile = (relativePath, content) => {
    fs.mkdirSync(path.dirname(relativePath), { recursive: true });
    fs.writeFileSync(relativePath, content);
};

describe('getGitChanges()', () => {
    test('detects added and modified rockspec files in HEAD commit', () => {
        withGitRepo(() => {
            const existing = 'rockspecs/github.com/foo/bar/pkg-1.0.0-1.rockspec';
            writeFile(existing, 'version = "1.0.0-1"\n');
            runGit(['add', existing]);
            runGit(['commit', '-m', 'add initial rockspec']);

            writeFile(existing, 'version = "1.0.0-2"\n');
            const added = 'rockspecs/github.com/foo/bar/pkg-1.1.0-1.rockspec';
            writeFile(added, 'version = "1.1.0-1"\n');
            runGit(['add', existing, added]);
            runGit(['commit', '-m', 'update and add rockspec']);

            const result = getGitChanges();
            assert.ok(result);
            const expectedSha = runGit(['rev-parse', 'HEAD']);
            const expectedTimestamp = runGit(['show', '-s', '--format=%cI', 'HEAD']);
            const addEntries = [...result.addOrUpdate.entries()].sort(([a], [b]) => a.localeCompare(b));
            assert.deepStrictEqual(addEntries, [
                [existing, expectedSha],
                [added, expectedSha]
            ]);
            assert.strictEqual(result.removals.size, 0);
            assert.equal(result.commitSha, expectedSha);
            assert.equal(result.committedAt, expectedTimestamp);
        });
    });

    test('collects removed rockspec files', () => {
        withGitRepo(() => {
            const removedPath = 'rockspecs/github.com/foo/bar/pkg-0.9.0-1.rockspec';
            writeFile(removedPath, 'version = "0.9.0-1"\n');
            runGit(['add', removedPath]);
            runGit(['commit', '-m', 'add rockspec to remove later']);

            runGit(['rm', removedPath]);
            runGit(['commit', '-m', 'remove outdated rockspec']);

            const result = getGitChanges();
            assert.ok(result);
            assert.strictEqual(result.addOrUpdate.size, 0);
            const expectedSha = runGit(['rev-parse', 'HEAD']);
            const expectedTimestamp = runGit(['show', '-s', '--format=%cI', 'HEAD']);
            assert.deepStrictEqual([...result.removals.entries()], [[removedPath, expectedSha]]);
            assert.equal(result.commitSha, expectedSha);
            assert.equal(result.committedAt, expectedTimestamp);
        });
    });

    test('returns null when HEAD commit has no .rockspec changes', () => {
        withGitRepo(() => {
            writeFile('README.md', '# initial\n');
            runGit(['add', 'README.md']);
            runGit(['commit', '-m', 'docs']);

            writeFile('README.md', '# updated\n');
            runGit(['add', 'README.md']);
            runGit(['commit', '-m', 'docs update']);

            const result = getGitChanges();
            assert.strictEqual(result, null);
        });
    });
});

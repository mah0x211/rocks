import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

import { getCurrentCommitSha } from '../../scripts/rockup-sync-gh-pages.mjs';

const withTempDir = (fn) => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'rocks-git-'));
    const previous = process.cwd();
    process.chdir(tmp);
    try {
        fn(tmp);
    } finally {
        process.chdir(previous);
        fs.rmSync(tmp, { recursive: true, force: true });
    }
};

const runGit = (args, options = {}) => {
    const result = spawnSync('git', args, { encoding: 'utf8', ...options });
    if (result.status !== 0) {
        throw new Error(result.stderr || `git ${args.join(' ')} failed`);
    }
    return result.stdout.trim();
};

describe('getCurrentCommitSha()', () => {
    test('returns HEAD SHA in a repository with commits', () => {
        withTempDir(() => {
            runGit(['init']);
            runGit(['config', 'user.name', 'Test User']);
            runGit(['config', 'user.email', 'test@example.com']);
            fs.writeFileSync('file.txt', 'hello');
            runGit(['add', 'file.txt']);
            runGit(['commit', '-m', 'initial commit']);

            const sha = getCurrentCommitSha();
            const expected = runGit(['rev-parse', 'HEAD']);

            assert.strictEqual(sha, expected);
            assert.match(sha, /^[0-9a-f]{40}$/);
        });
    });

    test('throws a descriptive error outside a git repository', () => {
        withTempDir(() => {
            assert.throws(() => {
                getCurrentCommitSha();
            }, (error) => {
                const message = String(error?.message ?? error);
                assert.match(message, /Failed to get current commit SHA/);
                return true;
            });
        });
    });

    test('throws when repository has no commits', () => {
        withTempDir(() => {
            runGit(['init']);

            assert.throws(() => {
                getCurrentCommitSha();
            }, (error) => {
                const message = String(error?.message ?? error);
                assert.match(message, /Failed to get current commit SHA/);
                return true;
            });
        });
    });
});

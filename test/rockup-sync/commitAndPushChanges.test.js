import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

import { commitAndPushChanges } from '../../scripts/rockup-sync-gh-pages.mjs';

const git = (args, options = {}) => {
    const result = spawnSync('git', args, { encoding: 'utf8', ...options });
    if (result.status !== 0) {
        throw new Error(result.stderr || `git ${args.join(' ')} failed`);
    }
    return result.stdout.trim();
};

const runGitDir = (gitDir, args) => {
    return git(['--git-dir', gitDir, ...args]);
};

const withTempRepo = (fn) => {
    const baseDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rocks-commit-'));
    const remoteDir = path.join(baseDir, 'remote.git');
    const workDir = path.join(baseDir, 'work');
    fs.mkdirSync(workDir);

    git(['init', '--bare', remoteDir]);
    git(['init'], { cwd: workDir });
    git(['config', 'user.name', 'Test User'], { cwd: workDir });
    git(['config', 'user.email', 'test@example.com'], { cwd: workDir });
    git(['remote', 'add', 'origin', remoteDir], { cwd: workDir });
    git(['branch', '-M', 'main'], { cwd: workDir });

    const previous = process.cwd();
    process.chdir(workDir);
    try {
        fn({ baseDir, workDir, remoteDir });
    } finally {
        process.chdir(previous);
        fs.rmSync(baseDir, { recursive: true, force: true });
    }
};

describe('commitAndPushChanges()', () => {
    test('commits and pushes staged artifacts', () => {
        withTempRepo(({ workDir, remoteDir }) => {
            fs.writeFileSync('rocks.db', 'initial');
            fs.writeFileSync('index.html', '<html></html>');
            fs.writeFileSync('manifest-5.1', 'manifest content');

            git(['add', '.'], { cwd: workDir });
            git(['commit', '-m', 'initial'], { cwd: workDir });
            git(['push', '-u', 'origin', 'main'], { cwd: workDir });

            const previousHead = git(['rev-parse', 'HEAD'], { cwd: workDir });
            const refMain = 'refs/heads/main';
            const previousRemoteHead = runGitDir(remoteDir, ['rev-parse', refMain]);

            fs.writeFileSync('rocks.db', 'updated');

            commitAndPushChanges();

            const head = git(['rev-parse', 'HEAD'], { cwd: workDir });
            const remoteHead = runGitDir(remoteDir, ['rev-parse', refMain]);
            assert.notStrictEqual(head, previousHead);
            assert.notStrictEqual(remoteHead, previousRemoteHead);

            const commitLog = git(['log', '-1', '--oneline'], { cwd: workDir });
            assert.match(commitLog, /chore\(rockup\): sync rocks\.db$/);

            const remoteCommitLog = runGitDir(remoteDir, ['log', '-1', '--oneline', refMain]);
            assert.match(remoteCommitLog, /chore\(rockup\): sync rocks\.db$/);

            const remoteRocksDb = runGitDir(remoteDir, ['show', `${refMain}:rocks.db`]);
            assert.equal(remoteRocksDb, 'updated');

            const status = git(['status', '--short'], { cwd: workDir });
            assert.equal(status, '');
        });
    });

    test('throws when git add fails in a non-repository directory', () => {
        const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rocks-commit-fail-'));
        const previousCwd = process.cwd();

        try {
            process.chdir(tempDir);
            let error;
            try {
                commitAndPushChanges();
                assert.fail('Expected commitAndPushChanges to throw');
            } catch (err) {
                error = err;
            }

            assert.ok(error instanceof Error);
            assert.match(error.message, /git add failed/);
        } finally {
            process.chdir(previousCwd);
            fs.rmSync(tempDir, { recursive: true, force: true });
        }
    });

    test('returns early when no staged changes exist', () => {
        withTempRepo(({ workDir }) => {
            fs.writeFileSync('rocks.db', 'initial');
            fs.writeFileSync('index.html', '<html></html>');
            fs.writeFileSync('manifest-5.1', 'manifest content');

            git(['add', '.'], { cwd: workDir });
            git(['commit', '-m', 'initial'], { cwd: workDir });

            const previousHead = git(['rev-parse', 'HEAD'], { cwd: workDir });

            commitAndPushChanges();

            const head = git(['rev-parse', 'HEAD'], { cwd: workDir });
            assert.equal(head, previousHead);

            const status = git(['status', '--short'], { cwd: workDir });
            assert.equal(status, '');
        });
    });
});

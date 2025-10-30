import { describe, test } from 'node:test';
import assert from 'node:assert/strict';

import { runCommand } from '../../scripts/rockup-sync-gh-pages.mjs';

const bufferToString = (value) => Buffer.isBuffer(value) ? value.toString('utf8') : value;

describe('runCommand()', () => {
    test('executes simple command successfully', () => {
        const result = runCommand('node', ['-e', 'process.stdout.write("ok");']);
        assert.strictEqual(result.status, 0);
        assert.strictEqual(bufferToString(result.stdout), 'ok');
    });

    test('throws descriptive error when command exits non-zero', () => {
        assert.throws(() => {
            runCommand('node', ['-e', 'process.exit(3);']);
        }, (error) => {
            const message = String(error?.message ?? error);
            assert.match(message, /node exited with code 3/);
            return true;
        });
    });

    test('throws when command binary is missing', () => {
        assert.throws(() => {
            runCommand('command-that-does-not-exist', []);
        }, (error) => {
            assert.strictEqual(error.code, 'ENOENT');
            return true;
        });
    });

    test('accepts additional spawn options and captures output', () => {
        const script = 'console.error("err");process.stdout.write("out");';
        const result = runCommand('node', ['-e', script], { encoding: 'utf8' });
        assert.strictEqual(result.stdout, 'out');
        assert.strictEqual(result.stderr, 'err\n');
    });

    test('supports stdio configuration such as ignore', () => {
        const result = runCommand('node', ['-e', 'process.stdout.write("ignored");'], { stdio: 'ignore' });
        assert.strictEqual(result.status, 0);
        assert.ok(result.stdout == null);
        assert.ok(result.stderr == null);
    });

    test('returns buffer output when no encoding is specified', () => {
        const result = runCommand('node', ['-e', 'process.stdout.write("buffer");']);
        assert.ok(Buffer.isBuffer(result.stdout));
        assert.strictEqual(result.stdout.toString('utf8'), 'buffer');
    });

    test('handles large stdout payloads', () => {
        const result = runCommand('node', ['-e', 'process.stdout.write("a".repeat(200000));']);
        assert.strictEqual(result.stdout.length, 200000);
    });

    test('propagates timeout errors from spawnSync', () => {
        assert.throws(() => {
            runCommand('node', ['-e', 'setTimeout(() => {}, 100);'], { timeout: 10 });
        }, (error) => {
            assert.strictEqual(error.code, 'ETIMEDOUT');
            return true;
        });
    });
});

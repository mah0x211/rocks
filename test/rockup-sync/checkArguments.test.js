import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import { checkArguments } from '../../scripts/rockup-sync-gh-pages.mjs';

class ProcessExitError extends Error {
    constructor(code) {
        super(`Process exited with code ${code}`);
        this.code = code;
    }
}

const captureExit = (args) => {
    const originalExit = process.exit;
    const originalWrite = process.stdout.write;
    const captured = [];
    let exitError = null;

    process.exit = (code) => {
        exitError = new ProcessExitError(code);
        throw exitError;
    };

    process.stdout.write = (chunk, encodingOrCallback, maybeCallback) => {
        const encoding = typeof encodingOrCallback === 'string' ? encodingOrCallback : undefined;
        const callback = typeof encodingOrCallback === 'function' ? encodingOrCallback : maybeCallback;
        const text = Buffer.isBuffer(chunk) ? chunk.toString(encoding) : String(chunk);
        captured.push(text);
        if (typeof callback === 'function') {
            callback();
        }
        return true;
    };

    try {
        checkArguments(args);
    } catch (err) {
        if (err !== exitError) {
            throw err;
        }
    } finally {
        process.exit = originalExit;
        process.stdout.write = originalWrite;
    }

    if (!exitError) {
        assert.fail('Expected checkArguments to call process.exit for unknown arguments');
    }

    return {
        exitCode: exitError.code,
        output: captured.join('')
    };
};

describe('Test checkArguments()', () => {
    test('returns default flags when no arguments are provided', () => {
        const result = checkArguments([]);
        assert.deepStrictEqual(result, {
            showHelp: false,
            commit: false
        });
    });

    test('enables commit flag when --commit is present', () => {
        const result = checkArguments(['--commit']);
        assert.deepStrictEqual(result, {
            showHelp: false,
            commit: true
        });
    });

    test('enables help flag when --help is present', () => {
        const result = checkArguments(['--help']);
        assert.deepStrictEqual(result, {
            showHelp: true,
            commit: false
        });
    });

    test('enables help flag when -h is present', () => {
        const result = checkArguments(['-h']);
        assert.deepStrictEqual(result, {
            showHelp: true,
            commit: false
        });
    });

    test('handles combination of --commit and help flags', () => {
        const result = checkArguments(['--commit', '--help']);
        assert.deepStrictEqual(result, {
            showHelp: true,
            commit: true
        });
    });

    test('exits with code 1 when an unknown argument is provided', () => {
        const { exitCode, output } = captureExit(['--unknown']);
        assert.strictEqual(exitCode, 1);
        assert.match(output, /Unknown argument\(s\): --unknown/);
        assert.match(output, /Usage: node rockup-sync-gh-pages\.mjs/);
    });

    test('lists all unknown arguments in the error message', () => {
        const { exitCode, output } = captureExit(['--foo', '--bar']);
        assert.strictEqual(exitCode, 1);
        assert.match(output, /Unknown argument\(s\): --foo, --bar/);
    });

    test('rejects when valid and unknown arguments are mixed', () => {
        const { exitCode, output } = captureExit(['--commit', '--weird']);
        assert.strictEqual(exitCode, 1);
        assert.match(output, /Unknown argument\(s\): --weird/);
    });

    test('supports duplicate flags without error', () => {
        const result = checkArguments(['--commit', '--commit', '-h', '-h']);
        assert.deepStrictEqual(result, {
            showHelp: true,
            commit: true
        });
    });
});

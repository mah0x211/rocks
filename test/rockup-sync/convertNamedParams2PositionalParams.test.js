import { describe, test } from 'node:test';
import assert from 'node:assert/strict';

import { convertNamedParams2PositionalParams } from '../../scripts/rockup-sync-gh-pages.mjs';

describe('convertNamedParams2PositionalParams()', () => {
    test('converts single named placeholders to positional parameters', () => {
        const { sql, params } = convertNamedParams2PositionalParams(
            'SELECT * FROM demo WHERE a = $foo AND b = $bar',
            { foo: 1, bar: 2 }
        );
        assert.strictEqual(sql, 'SELECT * FROM demo WHERE a = ? AND b = ?');
        assert.deepStrictEqual(params, [1, 2]);
    });

    test('keeps placeholders inside string literals untouched', () => {
        const { sql, params } = convertNamedParams2PositionalParams(
            "SELECT '$foo' AS literal, value FROM demo WHERE a = $foo",
            { foo: 42 }
        );
        assert.strictEqual(sql, "SELECT '$foo' AS literal, value FROM demo WHERE a = ?");
        assert.deepStrictEqual(params, [42]);
    });

    test('supports repeated named placeholders', () => {
        const { sql, params } = convertNamedParams2PositionalParams(
            'SELECT * FROM demo WHERE a = $foo OR b = $foo',
            { foo: 7 }
        );
        assert.strictEqual(sql, 'SELECT * FROM demo WHERE a = ? OR b = ?');
        assert.deepStrictEqual(params, [7, 7]);
    });

    test('throws when placeholder value is missing', () => {
        assert.throws(() => {
            convertNamedParams2PositionalParams('SELECT * FROM demo WHERE a = $missing', {});
        }, /Missing SQL parameter: missing/);
    });

    test('throws on invalid placeholder syntax', () => {
        assert.throws(() => {
            convertNamedParams2PositionalParams('SELECT * FROM demo WHERE a = $1');
        }, /Invalid SQL placeholder/);
    });
});

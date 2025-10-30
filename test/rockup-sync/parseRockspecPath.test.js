import { describe, test } from 'node:test';
import assert from 'node:assert/strict';

import { parseRockspecPath } from '../../scripts/rockup-sync-gh-pages.mjs';

const expectObject = (path, { host, owner, repo, filename }) => {
    const result = parseRockspecPath(path);
    assert.ok(result, `Expected parseRockspecPath to return object for ${path}`);
    assert.deepStrictEqual(result, {
        path,
        host,
        owner,
        repo,
        filename
    });
};

describe('Test parseRockspecPath()', () => {
    test('accepts canonical rockspec path', () => {
        expectObject('rockspecs/github.com/foo/bar/pkg-1.0.0-1.rockspec', {
            host: 'github.com',
            owner: 'foo',
            repo: 'bar',
            filename: 'pkg-1.0.0-1.rockspec'
        });
    });

    test('accepts various hosts', () => {
        expectObject('rockspecs/gitlab.com/a/b/c-2.3.4-1.rockspec', {
            host: 'gitlab.com',
            owner: 'a',
            repo: 'b',
            filename: 'c-2.3.4-1.rockspec'
        });
        expectObject('rockspecs/custom.host.example/a/bb/pkg.rockspec', {
            host: 'custom.host.example',
            owner: 'a',
            repo: 'bb',
            filename: 'pkg.rockspec'
        });
    });

    test('supports hyphenated and underscored segments', () => {
        expectObject('rockspecs/github.com/foo-bar/baz_qux/pkg-1-1.rockspec', {
            host: 'github.com',
            owner: 'foo-bar',
            repo: 'baz_qux',
            filename: 'pkg-1-1.rockspec'
        });
    });

    test('rejects paths without rockspecs/ prefix', () => {
        assert.strictEqual(parseRockspecPath('rocks/github.com/a/b/c.rockspec'), null);
        assert.strictEqual(parseRockspecPath('foo/rockspecs/github.com/a/b/c.rockspec'), null);
    });

    test('rejects non-.rockspec extensions', () => {
        assert.strictEqual(parseRockspecPath('rockspecs/github.com/a/b/c.txt'), null);
        assert.strictEqual(parseRockspecPath('rockspecs/github.com/a/b/c.rock'), null);
    });

    test('rejects paths with incorrect segment count', () => {
        assert.strictEqual(parseRockspecPath('rockspecs/github.com/a/b.rockspec'), null);
        assert.strictEqual(parseRockspecPath('rockspecs/github.com/a/b/c/d/e.rockspec'), null);
        assert.strictEqual(parseRockspecPath('rockspecs/github.com/a/b/c/d.rockspec'), null);
    });

    test('returns null for empty or falsy values', () => {
        assert.strictEqual(parseRockspecPath(''), null);
        assert.strictEqual(parseRockspecPath(null), null);
        assert.strictEqual(parseRockspecPath(undefined), null);
    });

    test('rejects absolute paths that bypass prefix check', () => {
        assert.strictEqual(parseRockspecPath('/rockspecs/github.com/a/b/c.rockspec'), null);
        assert.strictEqual(parseRockspecPath('file:///rockspecs/github.com/a/b/c.rockspec'), null);
    });

    test('handles repository names with dots and plus signs', () => {
        expectObject('rockspecs/github.com/foo/bar.baz+qux/pkg-1.rockspec', {
            host: 'github.com',
            owner: 'foo',
            repo: 'bar.baz+qux',
            filename: 'pkg-1.rockspec'
        });
    });
});

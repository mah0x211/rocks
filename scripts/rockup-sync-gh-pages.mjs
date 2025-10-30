#!/usr/bin/env node
/*
 * MIT License
 *
 * Copyright (c) 2025 Masatoshi Fukunaga
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import * as fs from 'node:fs';
import { spawnSync, execFileSync } from 'node:child_process';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

// Process stream and argv references for consistency
const STDOUT = process.stdout;
const STDERR = process.stderr;
const ARGV = process.argv;

/**
 * Logs a message to stdout
 * @param {string} message - The message to log
 */
function log(message) {
    STDOUT.write(`[rockup-sync] ${message}\n`);
}

/**
 * Logs an error message and exits with code 1
 * @param {string} message - The error message to log
 */
function fail(message) {
    STDERR.write(`[rockup-sync] ${message}\n`);
    process.exit(1);
}

function wrapError(prefix, err) {
    const detail = err instanceof Error && err.message ? err.message : String(err);
    return new Error(`${prefix}: ${detail}`);
}

/**
 * Executes a command and handles errors
 * @param {string} command - The command to execute
 * @param {string[]} args - Command arguments
 * @param {Object} options - Additional options for spawnSync
 * @returns {Object} The result of spawnSync
 * @throws {Error} If command execution fails
 */
export function runCommand(command, args, options = {}) {
    const result = spawnSync(command, args, options);
    if (result.error) {
        throw result.error;
    }
    if (result.status !== 0) {
        let errorMsg = `${command} exited with code ${result.status}`;
        if (result.stderr) {
            errorMsg += `\nstderr: ${result.stderr}`;
        }
        if (result.stdout) {
            errorMsg += `\nstdout: ${result.stdout}`;
        }
        throw new Error(errorMsg);
    }
    return result;
}

/**
 * Commits and pushes changes to git repository
 * @throws {Error} If git operations fail
 */
export function commitAndPushChanges() {
    // Add rocks.db, index.html, and manifest files
    try {
        runCommand('git', ['add', 'rocks.db', 'index.html', 'manifest*'], { stdio: 'inherit' });
    } catch (err) {
        throw wrapError('git add failed', err);
    }

    const diffCached = spawnSync('git', ['diff', '--cached', '--quiet']);
    if (diffCached.error) {
        throw new Error(`git diff --cached failed: ${diffCached.error.message}`);
    }
    if (diffCached.status === 0) {
        log('No staged changes after git add. Skipping commit.');
        return;
    }

    const commitMessage = 'chore(rockup): sync rocks.db';
    try {
        runCommand('git', ['commit', '-m', commitMessage], { stdio: 'inherit' });
    } catch (err) {
        throw wrapError('git commit failed', err);
    }

    try {
        runCommand('git', ['push', 'origin', 'HEAD'], { stdio: 'inherit' });
    } catch (err) {
        throw wrapError('git push failed', err);
    }
}

/**
 * Regenerates luarocks manifest and zip files
 * @throws {Error} If manifest generation fails
 */
export function regenerateManifest() {
    execFileSync('luarocks-admin', ['make_manifest', '.'], { stdio: 'inherit' });

    // Generate zip files for all Lua versions
    const luaVersions = ["5.1", "5.2", "5.3", "5.4"];
    for (const version of luaVersions) {
        const manifestFile = `manifest-${version}`;
        const zipFile = `${manifestFile}.zip`;

        // Remove existing zip file if it exists
        if (fs.existsSync(zipFile)) {
            fs.unlinkSync(zipFile);
        }

        // Create zip file containing the manifest using system zip command
        try {
            runCommand('zip', [zipFile, manifestFile], { stdio: 'pipe' });
        } catch (error) {
            throw wrapError(`Failed to create ${zipFile}`, error);
        }

        log(`Created ${zipFile} from ${manifestFile}`);
    }
}


/**
 * Converts SQL containing named placeholders into positional parameters.
 * @param {string} sql - SQL statement potentially containing $name placeholders.
 * @param {Object} paramsObj - Mapping from placeholder names to values.
 * @returns {{sql: string, params: any[]}} SQL with positional placeholders and parameter list.
 * @throws {Error} If a placeholder is invalid or missing from paramsObj.
 */
export function convertNamedParams2PositionalParams(sql, paramsObj = {}) {
    const params = [];
    let convertedSql = '';
    let i = 0;
    let quote = null;

    const length = sql.length;

    while (i < length) {
        const char = sql[i];

        if (quote) {
            convertedSql += char;

            if (char === quote) {
                const next = sql[i + 1];
                if (next === quote) {
                    convertedSql += next;
                    i += 2;
                    continue;
                }
                quote = null;
            }

            i += 1;
            continue;
        }

        if (char === "'" || char === '"' || char === '`') {
            quote = char;
            convertedSql += char;
            i += 1;
            continue;
        }

        if (char === '$') {
            const segment = sql.slice(i + 1);
            const match = segment.match(/^([A-Za-z_][A-Za-z0-9_]*)/);
            if (!match) {
                throw new Error(`Invalid SQL placeholder at position ${i}`);
            }

            const name = match[1];
            if (!Object.prototype.hasOwnProperty.call(paramsObj, name)) {
                throw new Error(`Missing SQL parameter: ${name}`);
            }

            params.push(paramsObj[name]);
            convertedSql += '?';
            i += match[0].length + 1;
            continue;
        }

        convertedSql += char;
        i += 1;
    }

    return { sql: convertedSql, params };
}

/**
 * Executes SQL with parameters and handles transactions
 * @param {string} sql - SQL statement to execute
 * @param {Object} paramsObj - Parameters object keyed by placeholder name
 * @throws {Error} If SQL execution fails
 */
export function runSQL(sql, paramsObj = {}) {
    const { sql: convertedSql, params } = convertNamedParams2PositionalParams(sql, paramsObj);
    const db = new DatabaseSync('rocks.db');
    try {
        db.exec("BEGIN TRANSACTION");

        const stmt = db.prepare(convertedSql);
        stmt.run(...params);

        db.exec("COMMIT");
    } catch (error) {
        try {
            db.exec("ROLLBACK");
        } catch (rollbackError) {
            // Ignore rollback errors
        }
        throw error;
    } finally {
        db.close();
    }
}

/**
 * Validates and parses a rockspec file path
 * @param {string} filePath - The file path to validate and parse
 * @returns {Object|null} Parsed path segments or null if invalid
 * @returns {string} returns.path - The original file path
 * @returns {string} returns.host - Host segment
 * @returns {string} returns.owner - Owner segment
 * @returns {string} returns.repo - Repository segment
 * @returns {string} returns.filename - Filename segment
 */
export function parseRockspecPath(filePath) {
    if (!filePath?.startsWith('rockspecs/') || !filePath.endsWith('.rockspec')) {
        return null;
    }

    const segments = filePath.split(/\/+/);
    if (segments.length !== 5) {
        return null;
    }

    return {
        path: filePath,
        host: segments[1],
        owner: segments[2],
        repo: segments[3],
        filename: segments[4]
    };
}

/**
 * Reads and validates a rockspec file, extracting metadata
 * @param {string} filePath - The rockspec file path
 * @returns {Object} Rockspec file data
 * @returns {Buffer} returns.buffer - File content as buffer
 * @returns {number} returns.fileSize - File size in bytes
 * @returns {string} returns.name - Package name extracted from filename
 * @returns {string} returns.version - Version (including revision) extracted from filename
 * @throws {Error} If file validation or reading fails
 */
export function readRockspec(filePath) {
    // Validate rockspec file using luarocks lint
    const absolute = path.resolve(filePath);
    try {
        runCommand('luarocks', ['lint', absolute], { stdio: 'pipe' });
    } catch (err) {
        throw wrapError(`Invalid rockspec file ${filePath}`, err);
    }

    // Extract name and full version (including revision) from filename using LuaRocks naming convention
    // Format: <name>-<version>-<revision>.rockspec
    const filename = path.basename(filePath);
    const match = filename.match(/^(.*)-([^-]+-\d+)\.rockspec$/);
    if (!match) {
        throw new Error(`Invalid rockspec filename format: ${filename}`);
    }
    const [, name, version] = match;

    const buffer = fs.readFileSync(absolute);
    return {
        buffer,
        fileSize: buffer.length,
        name,
        version
    };
}

/**
 * Handles addition or update of a rockspec file in the database
 * @param {string} filePath - Path to the rockspec file
 * @param {string} commitSha - Git commit SHA
 * @throws {Error} If database operations fail
 */
export function handleAddOrUpdate(filePath, commitSha, committedAt) {
    const parsed = parseRockspecPath(filePath);
    if (!parsed) {
        throw new Error(`Invalid rockspec path: expected format 'rockspecs/host/owner/repo/filename.rockspec', got: ${filePath}`);
    }
    const { host, owner, repo, filename } = parsed;

    // Read and parse the rockspec file
    const rockspec = readRockspec(filePath);
    const { buffer: contentBuffer, fileSize, name, version } = rockspec;
    const committedAtIso = committedAt ?? new Date().toISOString();

    const insertSql = `
        INSERT INTO rockspecs (
            host, owner, repo, filename, name, version, commit_sha, file_size, content,
            created_at, updated_at
        ) VALUES (
            $host, $owner, $repo, $filename, $name, $version, $commitSha, $fileSize, $content,
            $createdAt, $updatedAt
        )
        ON CONFLICT(host, owner, repo, filename)
        DO UPDATE SET
            commit_sha = excluded.commit_sha,
            file_size = excluded.file_size,
            content = excluded.content,
            updated_at = excluded.updated_at
    `;

    runSQL(insertSql, {
        host,
        owner,
        repo,
        filename,
        name,
        version,
        commitSha,
        fileSize,
        content: contentBuffer,
        createdAt: committedAtIso,
        updatedAt: committedAtIso
    });
    log(`Applied add/update for ${filePath}`);
}

/**
 * Handles removal of a rockspec file by deleting it from the database
 * @param {string} filePath - Path to the rockspec file
 * @throws {Error} If database operations fail
 */
export function handleRemoval(filePath) {
    const parsed = parseRockspecPath(filePath);
    if (!parsed) {
        throw new Error(`Invalid rockspec path: expected format 'rockspecs/host/owner/repo/filename.rockspec', got: ${filePath}`);
    }

    const { host, owner, repo, filename } = parsed;

    const sql = `
        DELETE FROM rockspecs
        WHERE host = $host AND owner = $owner AND repo = $repo AND filename = $filename
    `;

    runSQL(sql, {
        host,
        owner,
        repo,
        filename
    });
    log(`Marked removed: ${filePath}`);
}

/**
 * Gets rockspec file changes from git diff
 * @returns {Object|null} Changes object or null if no changes
 * @returns {Map<string, string>} returns.addOrUpdate - Files to add/update with commit SHAs
 * @returns {Map<string, string>} returns.removals - Files to remove with commit SHAs
 * @throws {Error} If git operations fail
 */
export function getGitChanges() {
    let output;
    try {
        const result = runCommand(
            'git',
            ['show', '--name-status', '--pretty=format:commit: %H%ndate: %cI%n', '--diff-filter=AMD', 'HEAD'],
            { encoding: 'utf8' }
        );
        output = result.stdout;
    } catch (err) {
        throw wrapError('Failed to obtain git diff', err);
    }
    const lines = output.split(/\r?\n/).filter(Boolean);
    if (lines.length < 2) {
        throw new Error('Unexpected git show output');
    }

    const commitMatch = lines[0].match(/^commit:\s+(.+)/);
    const dateMatch = lines[1].match(/^date:\s+(.+)/);
    if (!commitMatch || !dateMatch) {
        throw new Error('Failed to parse commit metadata from git show output');
    }

    const commitSha = commitMatch[1].trim();
    const committedAt = dateMatch[1].trim();

    const addOrUpdate = new Map();
    const removals = new Map();

    for (const line of lines.slice(2)) {
        const [status, filePath] = line.split(/\t+/);
        if (!status || !filePath) continue;
        if (!parseRockspecPath(filePath)) continue;

        if (status === 'A' || status === 'M') {
            addOrUpdate.set(filePath, commitSha);
            removals.delete(filePath);
        } else if (status === 'D') {
            removals.set(filePath, commitSha);
            addOrUpdate.delete(filePath);
        }
    }

    if (addOrUpdate.size === 0 && removals.size === 0) {
        log('No .rockspec changes detected. Nothing to do.');
        return null;
    }

    return { addOrUpdate, removals, commitSha, committedAt };
}

/**
 * Creates rocks.db if it doesn't exist with the proper table structure
 * @throws {Error} If database creation fails
 */
export function createRocksDbIfNotExists() {
    if (fs.existsSync('rocks.db')) {
        return; // Database already exists
    }

    log('Creating rocks.db database...');

    const createTableSQL = `
        CREATE TABLE rockspecs (
            id INTEGER PRIMARY KEY,
            host TEXT NOT NULL,
            owner TEXT NOT NULL,
            repo TEXT NOT NULL,
            filename TEXT NOT NULL,
            name TEXT NOT NULL,
            version TEXT NOT NULL,
            commit_sha TEXT,
            file_size INTEGER,
            content BLOB,
            created_at TEXT,
            updated_at TEXT,
            UNIQUE(host, owner, repo, filename)
        )
    `;
    const db = new DatabaseSync('rocks.db');
    try {
        db.exec(createTableSQL);
        log('Successfully created rocks.db database');
    } catch (error) {
        throw error;
    } finally {
        db.close();
    }
}

/**
 * Main function that orchestrates the rockup sync process
 * @throws {Error} If any step in the process fails
 */
function main() {
    // Create rocks.db if it doesn't exist
    createRocksDbIfNotExists();

    const changes = getGitChanges();
    if (!changes) {
        return;
    }

    const { addOrUpdate, removals, commitSha, committedAt } = changes;

    const args = checkArguments(ARGV.slice(2));
    const isDryRun = !args.commit;

    if (isDryRun) {
        log('[DRY RUN] Would apply the following changes:');
        for (const [filePath] of removals) {
            log(`[DRY RUN]   - Remove: ${filePath}`);
        }
        for (const [filePath] of addOrUpdate) {
            log(`[DRY RUN]   - Add/Update: ${filePath}`);
        }
        log('[DRY RUN] Would regenerate manifest files');
        log('[DRY RUN] Would commit and push changes');
        return;
    }

    // Apply removals
    for (const [filePath] of removals) {
        try {
            handleRemoval(filePath);
        } catch (err) {
            throw wrapError(`Failed to apply removal for ${filePath}`, err);
        }
    }

    // Apply additions and updates
    for (const [filePath] of addOrUpdate) {
        try {
            handleAddOrUpdate(filePath, commitSha, committedAt);
        } catch (err) {
            throw wrapError(`Failed to apply add/update for ${filePath}`, err);
        }
    }

    try {
        regenerateManifest();
    } catch (err) {
        throw wrapError('Failed to regenerate manifest', err);
    }

    commitAndPushChanges();
}

/**
 * Gets current commit SHA
 * @returns {string} Current commit SHA
 * @throws {Error} If git command fails
 */
export function getCurrentCommitSha() {
    const result = spawnSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' });
    if (result.status !== 0) {
        throw new Error(`Failed to get current commit SHA: ${result.stderr}`);
    }
    return result.stdout.trim();
}

/**
 * Shows usage information
 */
function showUsage() {
    console.log('Usage: node rockup-sync-gh-pages.mjs [options]');
    console.log('');
    console.log('Options:');
    console.log('  --commit    Actually apply changes (default is dry-run mode)');
    console.log('  --help      Show this help message');
    console.log('');
    console.log('Examples:');
    console.log('  node rockup-sync-gh-pages.mjs          # Dry-run mode (safe)');
    console.log('  node rockup-sync-gh-pages.mjs --commit # Apply changes');
}

/**
 * Checks command line arguments
 * @param {string[]} args - Command line arguments array
 * @returns {Object} Validated arguments object
 * @throws {Error} If unknown arguments are found
 */
export function checkArguments(args) {
    const validFlags = ['--commit', '--help', '-h'];

    // Check for unknown arguments
    const unknownArgs = args.filter(arg => !validFlags.includes(arg));
    if (unknownArgs.length > 0) {
        log(`Unknown argument(s): ${unknownArgs.join(', ')}`);
        showUsage();
        process.exit(1);
    }

    return {
        showHelp: args.includes('--help') || args.includes('-h'),
        commit: args.includes('--commit')
    };
}

/**
 * Start function that handles command line arguments and orchestrates execution
 */
function start() {
    const args = checkArguments(ARGV.slice(2));
    // Default to dry-run mode unless --commit flag is specified
    const isDryRun = !args.commit;
    // Store original commit SHA for dry-run mode
    const rollbackSha = isDryRun && getCurrentCommitSha();

    // Check for help flag
    if (args.showHelp) {
        showUsage();
        return;
    }

    if (isDryRun) {
        log(`[DRY RUN] Starting dry-run mode. Original commit: ${rollbackSha}`);
        log('[DRY RUN] Use --commit flag to actually apply changes');
    }

    let mainErr = null;
    try {
        // Execute main function
        main();
    } catch (e) {
        mainErr = e;
    }

    let rollbackErr = null;
    if (isDryRun) {
        log('[DRY RUN] Dry-run completed successfully');
        log(`[DRY RUN] Rollback SHA: ${rollbackSha}`);
        try {
            runCommand('git', ['reset', '--soft', rollbackSha], { stdio: 'inherit' });
            log('[DRY RUN] Rolled back to original commit');
        } catch (err) {
            rollbackErr = wrapError('Failed to rollback changes', err);
        }
    }

    const errorToReport = rollbackErr ?? mainErr;
    if (!errorToReport) {
        return;
    }

    const message = errorToReport instanceof Error ? errorToReport.message : String(errorToReport);
    fail(`Script execution failed: ${message}`);
}

// Execute start if run as script
if (import.meta.url === pathToFileURL(ARGV[1]).href) {
    start();
}

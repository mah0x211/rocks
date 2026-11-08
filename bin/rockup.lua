#!/usr/bin/env lua
--
-- MIT License
--
-- Copyright (c) 2026 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--
--- Command-line entry point for the registry sync tooling. It mutates rocks.db
--- and rebuilds the served directory; committing and pushing the master and
--- gh-pages branches is left to the calling workflow.
local script_dir = (arg[0] or ''):gsub('[^/]*$', '')
package.path = './lib/?.lua;' .. script_dir .. '../lib/?.lua;' .. package.path

local db = require('rockup.db')
local github = require('rockup.github')
local validation = require('rockup.validation')
local control = require('rockup.control')
local sync = require('rockup.sync')
local report = require('rockup.report')

local USAGE = [[
Usage: rockup <command> [targets...] [options]

Commands:
  sync                     Crawl all enabled sources and republish if changed
  seed                     Import existing served rockspecs as grandfathered
  pause | resume           Pause or resume periodic updates
  exclude <owner/repo>...  Exclude repositories and stop serving their rockspecs
  include <owner/repo>...  Re-include repositories and rescan them
  scan <owner/repo>        Scan a single repository once (not added to sources)
  add-source <owner>       Add a crawl source
  enable-source <owner>    Enable a crawl source
  disable-source <owner>   Disable a crawl source
  state                    Print excluded repositories and crawl sources

Options:
  --db <path>              Path to rocks.db (default: rocks.db)
  --serve-dir <path>       Served directory to rebuild (required for publishing)
  --force                  Bypass the keep-alive gate for sync
]]

local function fail(message)
    io.stderr:write('[rockup] ' .. message .. '\n')
    os.exit(1)
end

--- Parses argv into a command, positional targets, and options.
local function parse_args(argv)
    local opts = {
        db = 'rocks.db',
    }
    local targets = {}
    local command
    local i = 1
    while i <= #argv do
        local a = argv[i]
        if a == '--db' then
            i = i + 1
            if not argv[i] then
                fail('--db requires a value')
            end
            opts.db = argv[i]
        elseif a == '--serve-dir' then
            i = i + 1
            if not argv[i] then
                fail('--serve-dir requires a value')
            end
            opts.serve_dir = argv[i]
        elseif a == '--force' then
            opts.force = true
        elseif a == '--help' or a == '-h' then
            opts.help = true
        elseif not command then
            command = a
        else
            targets[#targets + 1] = a
        end
        i = i + 1
    end
    return command, targets, opts
end

local function require_serve_dir(opts)
    if not opts.serve_dir then
        fail('--serve-dir is required for this command')
    end
end

local function write_summary(text)
    local path = os.getenv('GITHUB_STEP_SUMMARY')
    if path then
        local fh = io.open(path, 'a')
        if fh then
            fh:write(text)
            fh:close()
            return
        end
    end
    io.write(text)
end

local function parse_targets(list)
    local targets = {}
    for _, str in ipairs(list) do
        local t = control.parse_target(str)
        if not t then
            fail('invalid target (expected owner/repo): ' .. str)
        end
        targets[#targets + 1] = t
    end
    return targets
end

local function run(command, targets, opts)
    local conn = db.open(opts.db)
    local gh = github.new()
    local validate = validation.new({
        github = gh,
    })
    local summary

    if command == 'sync' then
        require_serve_dir(opts)
        local aggregate = sync.run_all(conn, gh, {
            validate = validate,
            force = opts.force,
        })
        if aggregate.changed then
            sync.publish(conn, opts.serve_dir)
        end
        summary = report.format_sync(aggregate)
    elseif command == 'seed' then
        require_serve_dir(opts)
        local imported = sync.seed_existing(conn, opts.serve_dir)
        sync.publish(conn, opts.serve_dir)
        summary = string.format('## seed\n- imported %d rockspecs as grandfathered\n', imported)
    elseif command == 'pause' then
        control.pause(conn)
        summary = '## paused\n- periodic updates are paused\n'
    elseif command == 'resume' then
        control.resume(conn)
        summary = '## resumed\n- periodic updates are resumed\n'
    elseif command == 'exclude' or command == 'include' then
        require_serve_dir(opts)
        if not targets[1] then
            fail(command .. ' requires at least one owner/repo target')
        end
        local rep = control.set_ignore(conn, gh, parse_targets(targets), command == 'exclude', {
            validate = validate,
        })
        sync.publish(conn, opts.serve_dir)
        summary = report.format_control(command, rep)
    elseif command == 'scan' then
        require_serve_dir(opts)
        if not targets[1] then
            fail('scan requires an owner/repo target')
        end
        if targets[2] then
            fail('scan accepts a single owner/repo target')
        end
        local rep = control.scan_once(conn, gh, parse_targets(targets)[1], {
            validate = validate,
        })
        sync.publish(conn, opts.serve_dir)
        summary = report.format_control('scan ' .. targets[1], rep)
    elseif command == 'add-source' or command == 'enable-source' or command == 'disable-source' then
        if not targets[1] then
            fail(command .. ' requires an owner')
        end
        if command == 'add-source' then
            control.add_source(conn, {
                host = 'github.com',
                owner = targets[1],
            })
        else
            control.set_source_enabled(conn, 'github.com', targets[1], command == 'enable-source')
        end
        summary = report.format_state(conn:list_ignored_repos(), conn:list_sources())
    elseif command == 'state' then
        summary = report.format_state(conn:list_ignored_repos(), conn:list_sources())
    else
        conn:close()
        fail('unknown command: ' .. tostring(command) .. '\n\n' .. USAGE)
    end

    conn:close()
    write_summary(summary)
end

local command, targets, opts = parse_args(arg)
if opts.help or not command then
    io.write(USAGE)
    os.exit(command and 0 or 1)
end

local ok, err = pcall(run, command, targets, opts)
if not ok then
    fail(tostring(err))
end

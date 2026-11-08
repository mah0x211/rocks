rocks
=====

[![test](https://github.com/mah0x211/rocks/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/rocks/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/rocks/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/rocks)


mah0x211's luarocks repository.

The `gh-pages` branch is the published LuaRocks server
(`https://mah0x211.github.io/rocks/`). The `master` branch holds the tooling that
keeps it up to date and `rocks.db`, the authoritative state.

## Automated sync

The `sync` workflow periodically crawls the configured crawl sources (GitHub
owners) with the `gh` CLI, discovers rockspec additions, updates, and removals by
diffing each repository's git tree against `rocks.db`, validates them, and
rebuilds the served `gh-pages` registry (flat rockspec files plus LuaRocks
manifests).

- A rockspec is admitted only if `luarocks lint` passes, its declared package and
  version match its filename, and any pinned `source.tag` exists in the
  repository its `source.url` points at. The build is never run.
- Removals require a successful full repository enumeration and are capped by a
  deletion guard, so a transient API failure cannot wipe the registry.
- A name/version already published by a different repository is rejected.
- Each source backs off when it keeps producing no changes and resets on change;
  updates can be paused globally.

## Operating the registry

The tooling runs in the `ghcr.io/mah0x211/lua-ci` image on LuaJIT. Run the
workflow on a schedule, or manually via *Run workflow* with a command:

| Command | Effect |
|---|---|
| `sync` | Crawl all enabled sources and republish if changed |
| `pause` / `resume` | Pause or resume periodic updates |
| `exclude <owner/repo>...` | Stop serving a repository's rockspecs |
| `include <owner/repo>...` | Re-include and rescan a repository |
| `scan <owner/repo>` | Scan one repository once (not added to sources) |
| `add-source <owner>` | Add a crawl source |
| `enable-source` / `disable-source <owner>` | Toggle a crawl source |
| `state` | Report excluded repositories and crawl sources |

Locally, the same commands are available through `bin/rockup.lua`:

```sh
export LUA_PATH="./lib/?.lua;${LUA_PATH}"
lua bin/rockup.lua <command> [owner/repo...] --db rocks.db --serve-dir <gh-pages-worktree>
```

### Initial seed

To avoid a huge first crawl, seed `rocks.db` locally from the rockspecs already
published on `gh-pages`, then register a source and run the first sync:

```sh
git worktree add serve gh-pages
lua bin/rockup.lua seed --db rocks.db --serve-dir serve
lua bin/rockup.lua add-source mah0x211 --db rocks.db
lua bin/rockup.lua sync --force --db rocks.db --serve-dir serve
```

Seeded rockspecs are recorded as grandfathered (never auto-deleted). When a later
crawl finds the same rockspec in its source repository, it takes the entry over.

## Using the server

```sh
luarocks --server=https://mah0x211.github.io/rocks/ install <module>
```

Or add the server to `~/.luarocks/config.lua`:

```lua
rocks_servers = {
    "https://mah0x211.github.io/rocks/",
}
```

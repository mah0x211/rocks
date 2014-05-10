rocks
=====

mah0x211's luarocks repository

## Rocks Server URL

http://mah0x211.github.io/rocks/

## Command Line Option

```sh
luarocks --from=http://mah0x211.github.io/rocks/ install <module>
```

## Setup `~/.luarocks/config.lua` Configuration File

please add rocks server url to your `~/.luarocks/config.lua`, if you don't want to use command-line option.

```lua
rocks_servers = {
    "http://mah0x211.github.io/rocks/",
    -- default rocks server
    "http://luarocks.org/repositories/rocks"
}
```


package = "dump"
version = "0.1.0-1"
source = {
    url = "git://github.com/mah0x211/lua-dump.git",
    tag = "v0.1.0"
}
description = {
    summary = "Lua chunk loader module",
    homepage = "https://github.com/mah0x211/lua-dump",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        dump = "dump.lua"
    }
}


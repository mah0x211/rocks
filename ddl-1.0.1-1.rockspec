package = "ddl"
version = "1.0.1-1"
source = {
    url = "git://github.com/mah0x211/lua-ddl.git",
    tag = "v1.0.1"
}
description = {
    summary = "Lua as a Data Definition Language",
    homepage = "https://github.com/mah0x211/lua-ddl",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo >= 1.1.0",
    "path >= 1.0.1",
    "util >= 1.3.3"
}
build = {
    type = "builtin",
    modules = {
        ddl = "ddl.lua"
    }
}

package = "ddl"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-ddl.git",
    tag = "v1.0.0"
}
description = {
    summary = "Lua as a Data Definition Language",
    homepage = "https://github.com/mah0x211/lua-ddl",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo >= 1.0",
    "util >= 1.0",
    "path >= 1.0"
}
build = {
    type = "builtin",
    modules = {
        ddl = "ddl.lua"
    }
}

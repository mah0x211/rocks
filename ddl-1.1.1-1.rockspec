package = "ddl"
version = "1.1.1-1"
source = {
    url = "git+https://github.com/mah0x211/lua-ddl.git",
    tag = "v1.1.1"
}
description = {
    summary = "Lua as a Data Definition Language",
    homepage = "https://github.com/mah0x211/lua-ddl",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "path >= 1.0.4",
    "util >= 1.4.1"
}
build = {
    type = "builtin",
    modules = {
        ddl = "ddl.lua"
    }
}

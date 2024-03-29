package = "writelog"
version = "0.3.0-1"
source = {
    url = "git+https://github.com/mah0x211/lua-writelog.git",
    tag = "v0.3.0"
}
description = {
    summary = "simple logging module",
    homepage = "https://github.com/mah0x211/lua-writelog",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "util >= 1.5.1"
}
build = {
    type = "builtin",
    modules = {
        writelog = "writelog.lua",
    }
}

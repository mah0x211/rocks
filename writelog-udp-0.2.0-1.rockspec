package = "writelog-udp"
version = "0.2.0-1"
source = {
    url = "git+https://github.com/mah0x211/lua-writelog-udp.git",
    tag = "v0.2.0"
}
description = {
    summary = "udp logger module of writelog",
    homepage = "https://github.com/mah0x211/lua-writelog-udp",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "net >= 0.3.0",
    "writelog >= 0.6.0"
}
build = {
    type = "builtin",
    modules = {
        ["writelog.udp"] = "udp.lua",
    }
}
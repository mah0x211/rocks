package = "writelog-tcp"
version = "0.1.0-1"
source = {
    url = "git+https://github.com/mah0x211/lua-writelog-tcp.git",
    tag = "v0.1.0"
}
description = {
    summary = "tcp logger module of writelog",
    homepage = "https://github.com/mah0x211/lua-writelog-tcp",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "net >= 0.3.0",
    "writelog >= 0.5.0"
}
build = {
    type = "builtin",
    modules = {
        ["writelog.tcp"] = "tcp.lua",
    }
}
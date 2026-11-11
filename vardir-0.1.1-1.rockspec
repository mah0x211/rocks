package = "vardir"
version = "0.1.1-1"
source = {
    url = "git://github.com/mah0x211/lua-vardir.git",
    tag = "v0.1.1"
}
description = {
    summary = "",
    homepage = "https://github.com/mah0x211/lua-vardir",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        vardir = 'vardir.lua'
    }
}

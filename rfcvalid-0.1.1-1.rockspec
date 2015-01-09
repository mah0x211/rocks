package = "rfcvalid"
version = "0.1.1-1"
source = {
    url = "git://github.com/mah0x211/lua-rfcvalid.git",
    tag = "v0.1.1"
}
description = {
    summary = "RFC specification based validation modules",
    homepage = "https://github.com/mah0x211/lua-rfcvalid", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "util >= 1.3.2"
}
build = {
    type = "builtin",
    modules = {
        ["rfcvalid.2616"] = "lib/2616.lua",
        ["rfcvalid.6265"] = "lib/6265.lua"
    }
}


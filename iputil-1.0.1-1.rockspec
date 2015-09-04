package = "iputil"
version = "1.0.1-1"
source = {
    url = "git://github.com/mah0x211/lua-iputil.git",
    tag = "v1.0.1"
}
description = {
    summary = "ip address utility",
    homepage = "https://github.com/mah0x211/lua-iputil",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        iputil = {
            sources = { "src/iputil.c" }
        },
        ["iputil.table"] = "libs/table.lua"
    }
}

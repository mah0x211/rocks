package = "evpipe"
version = "scm-1"
source = {
    url = "gitrec://github.com/mah0x211/lua-evpipe.git"
}
description = {
    summary = "",
    homepage = "https://github.com/mah0x211/lua-evpipe",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "luarocks-fetch-gitrec >= 0.2",
    "net >= 0.19.1",
    "synops >= 0.3.3",
}
build = {
    type = "builtin",
    install = {
        bin = {
            evpipe = "bin/evpipe.lua"
        }
    },
    modules = {
        ['evpipe.main'] = "main.lua",
        ['evpipe.config'] = "lib/config.lua",
        ['evpipe.evdst'] = "evdst.lua",
        ['evpipe.evsrc'] = "evsrc.lua",
        ['evpipe.evsrc.http'] = "evsrc/http.lua",
        ['evpipe.evsrc.netdata'] = "evsrc/netdata.lua",
        ['evpipe.logger'] = "lib/logger.lua",
        ['evpipe.syscall'] = {
            incdirs = { "deps/lauxhlib" },
            sources = { "src/syscall.c" }
        },

    }
}

package = "tryout"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-tryout.git"
}
description = {
    summary = "test utility",
    homepage = "https://github.com/mah0x211/lua-util", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "ansicolors >= 1.0.2",
    "path >= 1.0.4",
    "process >= 1.4.2",
    "signal >= 1.0.0",
    "util >= 1.4.1"
}
build = {
    type = "builtin",
    modules = {
        ["tryout.sandbox"] = "lib/sandbox.lua",
        ["tryout.raise"] = "lib/raise.lua",
        ["tryout.hooks"] = "lib/hooks.lua",
        ["tryout.workdir"] = "lib/workdir.lua",
        ["tryout.run"] = "lib/run.lua",
    },
    install = {
        bin = {
            tryout = "tryout.lua"
        }
    }
}


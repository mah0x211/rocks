package = "pages"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-pages.git"
}
description = {
    summary = "lua template processor",
    detailed = [[lua template processor]],
    homepage = "https://github.com/mah0x211/lua-pages", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "tsukuyomi"
}
build = {
    type = "command",
    install_command = "sh install.sh",
    install = {
        lua = {
            pages = "pages.lua",
            ["pages.sandbox"] = "lib/sandbox.lua"
        }
    }
}


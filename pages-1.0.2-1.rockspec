package = "pages"
version = "1.0.2-1"
source = {
    url = "git://github.com/mah0x211/lua-pages.git",
    tag = "v1.0.2"
}
description = {
    summary = "lua template processor",
    homepage = "https://github.com/mah0x211/lua-pages", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "tsukuyomi >= 1.1.0"
}
build = {
    type = "builtin",
    modules = {
        pages = "pages.lua",
        ["pages.sandbox"] = "lib/sandbox.lua"
    }
}


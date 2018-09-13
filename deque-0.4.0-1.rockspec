package = "deque"
version = "0.4.0-1"
source = {
    url = "gitrec://github.com/mah0x211/lua-deque.git",
    tag = "v0.4.0"
}
description = {
    summary = "double-ended queue",
    homepage = "https://github.com/mah0x211/lua-deque",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "luarocks-fetch-gitrec >= 0.2"
}
build = {
    type = "builtin",
    modules = {
        deque = {
            incdirs = {
                "deps/lauxhlib"
            },
            sources = {
                "src/deque.c"
            }
        }
    }
}

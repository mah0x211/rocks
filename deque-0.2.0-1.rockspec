package = "deque"
version = "0.2.0-1"
source = {
    url = "git://github.com/mah0x211/lua-deque.git",
    tag = "v0.2.0"
}
description = {
    summary = "double-ended queue",
    homepage = "https://github.com/mah0x211/lua-deque",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        deque = "deque.lua"
    }
}

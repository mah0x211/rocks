package = "session"
version = "1.0.0-1"
source = {
    url = "git://github.com/mah0x211/lua-session.git",
    tag = "v1.0.0"
}
description = {
    summary = "session module.",
    homepage = "https://github.com/mah0x211/lua-session", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo >= 1.1.0",
    "util >= 1.2.0",
    "blake2 >= 1.0.0",
    "cookie >= 1.1.1",
    "process >= 1.0.0"
}
build = {
    type = "builtin",
    modules = {
        session = "session.lua",
        ["session.item"] = "lib/item.lua",
        ["session.proxy"] = "lib/proxy.lua"
    }
}


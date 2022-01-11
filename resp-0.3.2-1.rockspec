package = "resp"
version = "0.3.2-1"
source = {
    url = "git+https://github.com/mah0x211/lua-resp.git",
    tag = "v0.3.2"
}
description = {
    summary = "RESP (REdis Serialization Protocol) parser",
    homepage = "https://github.com/mah0x211/lua-resp",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        resp = "resp.lua"
    }
}


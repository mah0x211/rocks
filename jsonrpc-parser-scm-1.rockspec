package = "jsonrpc-parser"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-jsonrpc-parser.git"
}
description = {
    summary = "JSON-RPC 2.0 Message Parser",
    homepage = "https://github.com/mah0x211/lua-jsonrpc-parser",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "lua-cjson >= 2.1.0"
}
build = {
    type = "builtin",
    modules = {
        ["jsonrpc.parser"] = "parser.lua"
    }
}

package = "mime"
version = "dev-1"
source = {
    url = "git+https://github.com/mah0x211/lua-mime.git",
}
description = {
    summary = "MIME type utility module",
    homepage = "https://github.com/mah0x211/lua-mime",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "metamodule >= 0.5.0",
    "regex >= 0.2.0",
}
build = {
    type = "builtin",
    modules = {
        ["mime"] = "mime.lua",
        ["mime.default"] = "lib/default.lua",
        ["mime.parser"] = "lib/parser.lua",
    },
}

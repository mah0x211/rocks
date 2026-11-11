package = "string-random"
version = "0.4.0-1"
source = {
    url = "git+https://github.com/mah0x211/lua-string-random.git",
    tag = "v0.4.0",
}
description = {
    summary = "generate a random string.",
    homepage = "https://github.com/mah0x211/lua-string-random",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "base32 >= 0.1.0",
    "base64mix >= 1.1.1",
    "sfmt >= 1.5.4",
    "os-urandom >= 0.2.0",
}
build = {
    type = "builtin",
    modules = {
        ["string.random"] = "random.lua",
    },
}

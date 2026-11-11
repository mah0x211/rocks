package = "siphash"
version = "1.0.1-1"
source = {
    url = "git://github.com/mah0x211/lua-siphash.git",
    tag = "v1.0.1"
}
description = {
    summary = "siphash module",
    homepage = "https://github.com/mah0x211/lua-siphash",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        siphash = {
            sources = { "src/siphash.c" },
        }
    }
}


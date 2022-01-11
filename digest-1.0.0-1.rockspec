package = "digest"
version = "1.0.0-1"
source = {
    url = "git+https://github.com/mah0x211/lua-digest.git",
    tag = "v1.0.0"
}
description = {
    summary = "message digest module.",
    homepage = "https://github.com/mah0x211/lua-digest", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "jose >= 0.1.0",
    "siphash >= 1.0.1"
}
build = {
    type = "builtin",
    modules = {
        digest = "digest.lua"
    }
}

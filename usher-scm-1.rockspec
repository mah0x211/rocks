package = "usher"
version = "scm-1"
source = {
    url = "gitrec://github.com/mah0x211/lua-usher.git"
}
description = {
    summary = "libusher bindings for lua",
    homepage = "https://github.com/mah0x211/lua-usher",
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
        usher = {
            sources = {
                "src/usher.c",
                "deps/libusher/src/usher.c",
                "deps/libusher/src/segment.c"
            },
            incdirs = { 
                "deps/libusher/src"
            }
        }
    }
}

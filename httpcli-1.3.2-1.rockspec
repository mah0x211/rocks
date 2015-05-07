package = "httpcli"
version = "1.3.2-1"
source = {
    url = "git://github.com/mah0x211/lua-httpcli.git",
    tag = "v1.3.2"
}
description = {
    summary = "HTTP client module",
    homepage = "https://github.com/mah0x211/lua-httpcli", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo >= 1.1.0",
    "httpconsts >= 1.0.1",
    "lua-cjson >= 2.1.0",
    "luasec >= 0.5-2",
    "process >= 1.4.1",
    "url >= 1.0.1",
    "util >= 1.3.3",
}
build = {
    type = "builtin",
    modules = {
        httpcli = 'httpcli.lua',
        ["httpcli.luasocket"] = "lib/luasocket.lua"
    }
}


package = "cache-resty-memcached"
version = "0.1.0-1"
source = {
    url = "git+https://github.com/mah0x211/lua-cache-resty-memcached.git",
    tag = "v0.1.0"
}
description = {
    summary = "resty-memcached cache storage plugin for lua-cache module.",
    homepage = "https://github.com/mah0x211/lua-cache-resty-memcached", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "cache >= 1.0.1",
    "halo >= 1.1.0",
    "lua-cjson >= 2.1.0",
    "util >= 1.3.3"
}
build = {
    type = "builtin",
    modules = {
        ['cache.resty.memcached'] = "memcached.lua"
    }
}


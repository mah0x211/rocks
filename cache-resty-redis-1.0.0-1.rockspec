package = "cache-resty-redis"
version = "1.0.0-1"
source = {
    url = "git://github.com/mah0x211/lua-cache-resty-redis.git",
    tag = "v1.0.0"
}
description = {
    summary = "resty-redis cache storage plugin for lua-cache module.",
    homepage = "https://github.com/mah0x211/lua-cache-resty-redis", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "util >= 1.2",
    "lua-cjson >= 2.1.0",
    "halo >= 1.1.0",
    "cache >= 1.0.1",
}
build = {
    type = "builtin",
    modules = {
        ['cache.resty.redis'] = "redis.lua"
    }
}


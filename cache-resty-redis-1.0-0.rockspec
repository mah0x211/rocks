package = "cache-resty-redis"
version = "1.0-0"
source = {
    url = "git://github.com/mah0x211/lua-cache-resty-redis.git"
}
description = {
    summary = "redis plugin for lua-cache",
    homepage = "https://github.com/mah0x211/lua-cache-resty-redis", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "util >= 1.1",
    "lua-cjson >= 2.1.0",
    "halo >= 1.0",
    "cache >= 1.0",
}
build = {
    type = "builtin",
    modules = {
        ['cache.resty.redis'] = "redis.lua"
    }
}


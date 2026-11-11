package = "cache-etcd"
version = "1.0.1-1"
source = {
    url = "git://github.com/mah0x211/lua-cache-etcd.git",
    tag = "v1.0.1"
}
description = {
    summary = "etcd cache storage plugin for lua-cache module.",
    homepage = "https://github.com/mah0x211/lua-cache-etcd", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "httpconsts >= 1.0-1",
    "util >= 1.2.0",
    "halo >= 1.1",
    "etcd >= 0.11.0",
    "cache >= 1.0.1"
}
build = {
    type = "builtin",
    modules = {
        ['cache.etcd'] = "etcd.lua"
    }
}


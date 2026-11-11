package = "cache-etcd-resty"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-cache-etcd-resty.git"
}
description = {
    summary = "etcd-resty cache storage plugin for lua-cache module.",
    homepage = "https://github.com/mah0x211/lua-cache-etcd-resty", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo >= 1.1",
    "cache-etcd >= 1.0.0"
}
build = {
    type = "builtin",
    modules = {
        ['cache.etcd.resty'] = "resty.lua"
    }
}


package = "net-memcached"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-net-memcached.git"
}
description = {
    summary = "memcached client module",
    homepage = "https://github.com/mah0x211/lua-net-memcached",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "net >= 0.2.0"
}
build = {
    type = "builtin",
    modules = {
        ['net.memcached.client'] = "lib/client.lua",
    }
}


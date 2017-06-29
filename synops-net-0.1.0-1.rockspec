package = "synops-net"
version = "0.1.0-1"
source = {
    url = "git://github.com/mah0x211/lua-synops-net.git",
    tag = "v0.1.0"
}
description = {
    summary = "synops-net module",
    homepage = "https://github.com/mah0x211/lua-synops-net",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "net >= 0.10.0",
    "synops >= 0.1.0"
}
build = {
    type = "builtin",
    modules = {
        ['synops.net'] = "net.lua",
        ['synops.net.dgram'] = "lib/dgram.lua",
        ['synops.net.dgram.inet'] = "lib/dgram/inet.lua",
        ['synops.net.dgram.unix'] = "lib/dgram/unix.lua",
        ['synops.net.stream'] = "lib/stream.lua",
        ['synops.net.stream.inet'] = "lib/stream/inet.lua",
        ['synops.net.stream.unix'] = "lib/stream/unix.lua",
    }
}


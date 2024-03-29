package = "net"
version = "0.5.2-1"
source = {
    url = "git+https://github.com/mah0x211/lua-net.git",
    tag = "v0.5.2"
}
description = {
    summary = "net module",
    homepage = "https://github.com/mah0x211/lua-net",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo >= 1.1.8",
    "llsocket >= 0.1.1"
}
build = {
    type = "builtin",
    modules = {
        net = "net.lua",
        ['net.stream'] = "lib/stream.lua",
        ['net.stream.inet'] = "lib/stream/inet.lua",
        ['net.stream.unix'] = "lib/stream/unix.lua",
        ['net.dgram'] = "lib/dgram.lua",
        ['net.dgram.inet'] = "lib/dgram/inet.lua",
        ['net.dgram.unix'] = "lib/dgram/unix.lua"
    }
}


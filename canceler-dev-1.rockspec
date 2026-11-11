package = "canceler"
version = "dev-1"
source = {
    url = "git+https://github.com/mah0x211/lua-canceler.git",
}
description = {
    summary = "The canceler module provides a way to manage cancellation and timeout of operations.",
    homepage = "https://github.com/mah0x211/lua-canceler",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "time-clock >= 0.4.0",
    "errno >= 0.3.0",
    "metamodule >= 0.4.0",
}
build = {
    type = "builtin",
    modules = {
        canceler = "canceler.lua",
    },
}

package = "rmdir"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-rmdir.git",
}
description = {
    summary = "remove a directory file.",
    homepage = "https://github.com/mah0x211/lua-rmdir",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "error >= 0.11.0",
    "errno >= 0.4.0",
    "fstat >= 0.2.2",
    "opendir >= 0.2.1",
    "os-remove >= 0.1.0",
}
build = {
    type = "builtin",
    modules = {
        rmdir = "rmdir.lua",
    },
}

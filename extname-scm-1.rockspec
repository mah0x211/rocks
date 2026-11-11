rockspec_format = "3.0"
package = "extname"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-extname.git",
}
description = {
    summary = "extract the extension part of a pathname.",
    homepage = "https://github.com/mah0x211/lua-extname",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga"
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        extname = "extname.lua"
    }
}

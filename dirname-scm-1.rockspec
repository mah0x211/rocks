rockspec_format = "3.0"
package = "dirname"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-dirname.git",
}
description = {
    summary = "extract the directory part of a pathname.",
    homepage = "https://github.com/mah0x211/lua-dirname",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga"
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        dirname = "dirname.lua"
    }
}

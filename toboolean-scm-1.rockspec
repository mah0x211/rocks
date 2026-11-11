package = "toboolean"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-toboolean.git"
}
description = {
    summary = "string to boolean conversion module",
    homepage = "https://github.com/mah0x211/lua-toboolean",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        toboolean = "toboolean.lua",
    }
}


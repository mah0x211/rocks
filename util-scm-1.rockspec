package = "util"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-util.git"
}
description = {
    summary = "utility functions",
    homepage = "https://github.com/mah0x211/lua-util", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        util = "lib/util.lua",
        ["util.is"] = "lib/is.lua",
        ["util.typeof"] = "lib/typeof.lua",
        ["util.string"] = "lib/string.lua",
        ["util.table"] = "lib/table.lua"
    }
}


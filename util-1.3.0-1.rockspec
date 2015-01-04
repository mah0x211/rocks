package = "util"
version = "1.3.0-1"
source = {
    url = "git://github.com/mah0x211/lua-util.git",
    tag = "v1.3.0"
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
        ["util.typeof"] = "lib/typeof.lua",
        ["util.string"] = "lib/string.lua",
        ["util.table"] = "lib/table.lua"
    }
}


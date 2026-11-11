package = "writelog-file"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-writelog-file.git"
}
description = {
    summary = "file logger module of writelog",
    homepage = "https://github.com/mah0x211/lua-writelog-file",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "writelog >= 0.5.0"
}
build = {
    type = "builtin",
    modules = {
        ["writelog.file"] = "file.lua",
    }
}
package = "nsqpp"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-nsqpp.git"
}
description = {
    summary = "NSQ protocol parser",
    homepage = "https://github.com/mah0x211/lua-nsqpp",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        nsqp = "nsqpp.lua",
        ["nsqpp.util"] = {
            sources = {
                "src/util.c"
            }
        }
    }
}

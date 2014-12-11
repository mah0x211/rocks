package = "authnz"
version = "0.1.0-1"
source = {
    url = "git://github.com/mah0x211/lua-authnz.git",
    tag = "v0.1.0"
}
description = {
    summary = "auth module",
    homepage = "https://github.com/mah0x211/lua-authnz", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "util >= 1.2.1",
    "process >= 1.0.0",
    "halo >= 1.1.0",
    "httpcli >= 1.1.3",
    "blake2 >= 1.0.0",
    "url >= 1.0.1",
    "date >= 2.1.1",
    "jose >= 0.1.0"
}
build = {
    type = "builtin",
    modules = {
        authnz = "authnz.lua",
        ["authnz.openidc"] = "lib/openidc.lua",
        ["authnz.google"] = "openidc/google.lua",
        ["authnz.oauth2"] = "lib/oauth2.lua",
        ["authnz.dropbox"] = "oauth2/dropbox.lua"
    }
}


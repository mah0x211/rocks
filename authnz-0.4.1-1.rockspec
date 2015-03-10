package = "authnz"
version = "0.4.1-1"
source = {
    url = "git://github.com/mah0x211/lua-authnz.git",
    tag = "v0.4.1"
}
description = {
    summary = "auth module",
    homepage = "https://github.com/mah0x211/lua-authnz", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "date >= 2.1.1",
    "halo >= 1.1.2",
    "httpcli >= 1.3.0",
    "httpcli-resty >= 1.1.0",
    "jose >= 0.1.0",
    "lua-cjson >= 2.1.0",
    "process >= 1.4.0",
    "siphash >= 1.0.0",
    "url >= 1.0.1",
    "util >= 1.4.1"
}
build = {
    type = "builtin",
    modules = {
        authnz = "authnz.lua",
        ["authnz.openidc"]          = "lib/openidc.lua",
        ["authnz.google"]           = "openidc/google.lua",
        ["authnz.oauth2"]           = "lib/oauth2.lua",
        ["authnz.dropbox"]          = "oauth2/dropbox.lua",
        ["authnz.client.dropbox"]   = "client/dropbox.lua"
    }
}


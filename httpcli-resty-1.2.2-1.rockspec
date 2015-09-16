package = "httpcli-resty"
version = "1.2.2-1"
source = {
    url = "git://github.com/mah0x211/lua-httpcli-resty.git",
    tag = "v1.2.2"
}
description = {
    summary = "HTTP client module for OpenResty",
    homepage = "https://github.com/mah0x211/lua-httpcli-resty", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "httpcli >= 1.3.1"
}
build = {
    type = "builtin",
    modules = {
        ["httpcli.resty"] = "resty.lua",
    }
}


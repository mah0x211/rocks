package = "session"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-session.git",
}
description = {
    summary = "session module.",
    homepage = "https://github.com/mah0x211/lua-session",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "base32 >= 0.1.0",
    "cache >= 1.3.1",
    "cookie >= 1.3.1",
    "error >= 0.14.0",
    "lauxhlib >= 0.6.1",
    "metamodule >= 0.5.0",
    "string-random >= 0.4.0",
    "time-clock >= 0.4.1",
}
build = {
    type = "builtin",
    modules = {
        ["session"] = "session.lua",
        ["session.cookie"] = "lib/cookie.lua",
        ["session.idgen"] = "lib/idgen.lua",
    },
}


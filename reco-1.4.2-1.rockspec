package = "reco"
version = "1.4.2-1"
source = {
    url = "git+https://github.com/mah0x211/lua-reco.git",
    tag = "v1.4.2"
}
description = {
    summary = "reusable coroutine module",
    homepage = "https://github.com/mah0x211/lua-reco",
    license = "MIT",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        reco = {
            sources = { "src/reco.c" }
        }
    }
}


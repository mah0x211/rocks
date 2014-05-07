package = "coepoll"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-coepoll.git"
}
description = {
    summary = "epoll module",
    homepage = "https://github.com/mah0x211/lua-coepoll",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        coepoll = {
            sources = { 
                "src/lepoll.c",
                "src/loop.c",
                "src/sentry.c",
                "src/signal.c",
                "src/timer.c",
                "src/reader.c",
                "src/writer.c"
            },
            libraries = { "rt" }
        }
    }
}


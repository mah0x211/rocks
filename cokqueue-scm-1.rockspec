package = "cokqueue"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-cokqueue.git"
}
description = {
    summary = "kqueue module",
    homepage = "https://github.com/mah0x211/lua-cokqueue",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        cokqueue = {
            sources = { 
                "src/lkqueue.c",
                "src/loop.c",
                "src/sentry.c",
                "src/signal.c",
                "src/timer.c",
                "src/reader.c",
                "src/writer.c"
            }
        }
    }
}


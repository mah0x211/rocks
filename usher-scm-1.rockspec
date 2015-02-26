package = "usher"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-usher.git"
}
description = {
    summary = "libusher bindings for lua",
    homepage = "https://github.com/mah0x211/lua-usher",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
external_dependencies = {
    USHER = {
        header = "usher.h",
        library = "usher"
    }
}
build = {
    type = "builtin",
    modules = {
        usher = {
            sources = { "src/usher.c" },
            libraries = { "usher" },
            incdirs = { 
                "$(USHER_INCDIR)"
            },
            libdirs = {
                "$(USHER_LIBDIR)"
            }
        }
    }
}

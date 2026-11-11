package = "icu4l"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-icu4l.git"
}
description = {
    summary = "icu4c bindings for lua",
    homepage = "https://github.com/mah0x211/lua-icu4l",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
external_dependencies = {
    ICU4C = {
        header = "unicode/ucsdet.h"
    }
}
build = {
    type = "builtin",
    modules = {
        icu4l = "icu4l.lua",
        ['icu4l.charset'] = {
            sources = {
                "src/charset.c",
            },
            libraries = {
                "icui18n",
                "icuuc"
            },
            incdirs = { 
                "$(ICU4C_INCDIR)"
            },
            libdirs = { 
                "$(ICU4C_LIBDIR)"
            }
        }
    }
}

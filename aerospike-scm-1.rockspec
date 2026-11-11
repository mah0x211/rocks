package = "aerospike"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-aerospike.git"
}
description = {
    summary = "aerospike client c bindings for lua",
    homepage = "https://github.com/mah0x211/lua-aerospike",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
external_dependencies = {
    AEROSPIKE = {
        header = "aerospike/aerospike.h",
        library = "aerospike"
    }
}
build = {
    platforms = {
        linux = {
            build_variables = {
                PLATFORM_LDFLAGS = "-lrt"
            }
        }
    },
    type = "make",
    build_variables = {
        PACKAGE         = "aerospike",
        SRCDIR          = "src",
        CFLAGS          = "$(CFLAGS)",
        WARNINGS        = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare",
        CPPFLAGS        = "-I$(LUA_INCDIR) -I$(AEROSPIKE_INCDIR) -I$(AEROSPIKE_INCDIR)/ck",
        LDFLAGS         = "$(LIBFLAG)",
        LIBS            = "$(AEROSPIKE_LIBDIR)/libaerospike.a -lssl -lcrypto -lpthread -lz",
        LIB_EXTENSION   = "$(LIB_EXTENSION)"
    },
    install_variables = {
        PACKAGE         = "aerospike",
        SRCDIR          = "src",
        LIBDIR          = "$(LIBDIR)",
        PREFIX          = "$(PREFIX)",
        LIB_EXTENSION   = "$(LIB_EXTENSION)"
    }
}



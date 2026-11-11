package = "os-urandom"
version = "0.1.0-1"
source = {
    url = "git+https://github.com/mah0x211/lua-os-urandom.git",
    tag = "v0.1.0",
}
description = {
    summary = "for safely obtaining random bytes and random integers from the operating system's entropy source /dev/urandom.",
    homepage = "https://github.com/mah0x211/lua-os-urandom",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "errno >= 0.5.0",
    "lauxhlib >= 0.6.2",
}
build = {
    type = "make",
    build_variables = {
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        CFLAGS = "$(CFLAGS)",
        WARNINGS = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare",
        CPPFLAGS = "-I$(LUA_INCDIR)",
        LDFLAGS = "$(LIBFLAG)",
        OS_URANDOM_COVERAGE = "$(OS_URANDOM_COVERAGE)",
    },
    install_variables = {
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        INST_LIBDIR = "$(LIBDIR)/os/",
    },
}

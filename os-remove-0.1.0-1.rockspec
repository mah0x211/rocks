package = "os-remove"
version = "0.1.0-1"
source = {
    url = "git+https://github.com/mah0x211/lua-os-remove.git",
    tag = "v0.1.0",
}
description = {
    summary = "A drop-in replacement for the built-in file removal function, but with easier, portable error handling via structured error objects instead of errno values.",
    homepage = "https://github.com/mah0x211/lua-os-remove",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "errno >= 0.5.0",
}
build = {
    type = "make",
    build_variables = {
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        CFLAGS = "$(CFLAGS)",
        WARNINGS = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare",
        CPPFLAGS = "-I$(LUA_INCDIR)",
        LDFLAGS = "$(LIBFLAG)",
        OS_REMOVE_COVERAGE = "$(OS_REMOVE_COVERAGE)",
    },
    install_variables = {
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        INST_LIBDIR = "$(LIBDIR)/os/",
    },
}

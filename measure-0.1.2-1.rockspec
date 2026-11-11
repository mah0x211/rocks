package = "measure"
version = "0.1.2-1"
source = {
    url = "git+https://github.com/mah0x211/lua-measure.git",
    tag = "v0.1.2",
}
description = {
    summary = "measure is the benchmarking tool for Lua.",
    homepage = "https://github.com/mah0x211/lua-measure",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "chdir >= 0.2.0",
}
build = {
    type = 'make',
    build_variables = {
        PACKAGE_NAME = "measure",
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        CFLAGS = "$(CFLAGS)",
        CPPFLAGS = "-I$(LUA_INCDIR)",
        LDFLAGS = "$(LIBFLAG)",
        WARNINGS = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare",
    },
    install_variables = {
        PACKAGE_NAME = "measure",
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        BINDIR = "$(BINDIR)",
        LIBDIR = "$(LIBDIR)",
        LUADIR = "$(LUADIR)",
    },
}

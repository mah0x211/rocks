package = "string-natcmp"
version = "0.1.0-1"
source = {
    url = "git+https://github.com/mah0x211/lua-string-natcmp.git",
    tag = "v0.1.0",
}
description = {
    summary = "Natural order string comparison function for Lua with full UTF-8 support.",
    homepage = "https://github.com/mah0x211/lua-string-natcmp",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "make",
    build_variables = {
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        CFLAGS = "$(CFLAGS)",
        WARNINGS = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare",
        CPPFLAGS = "-I$(LUA_INCDIR)",
        LDFLAGS = "$(LIBFLAG)",
        STRING_NATCMP_COVERAGE = "$(STRING_NATCMP_COVERAGE)",
    },
    install_variables = {
        LIB_EXTENSION = "$(LIB_EXTENSION)",
        INST_CLIBDIR = "$(LIBDIR)/string",
    },
}

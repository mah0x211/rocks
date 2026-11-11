rockspec_format = "3.0"
package = "dlopen"
version = "dev-1"
source = {
    url = "git+https://github.com/mah0x211/lua-dlopen.git",
}
description = {
    summary = "Call C functions in shared libraries using libffi for Lua.",
    detailed = [[`dlopen` provides Lua bindings for calling C functions in shared libraries using `dlopen` functions and `libffi`.]],
    homepage = "https://github.com/mah0x211/lua-dlopen",
    maintainer = "Masatoshi Fukunaga",
    license = "MIT",
}
dependencies = {
    "lua >= 5.1",
}
external_dependencies = {}
build_dependencies = {
    "luarocks-build-hooks >= 0.6.0",
    "configh >= 0.3.0",
}
build = {
    type = "hooks",
    before_build = {
        "$(pkgconfig)",
        "$(extra-vars)",
        "$(configh)",
        -- "preprocess.lua",
    },
    pkgconfig_dependencies = {
        ["LIBFFI"] = {},
    },
    extra_variables = {
        CFLAGS = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare",
    },
    conditional_variables = {
        DLOPEN_COVERAGE = {
            CFLAGS = "--coverage",
            LIBFLAG = "--coverage",
        },
    },
    modules = {
        dlopen = {
            sources = {
                "src/dlopen.c",
            },
            libraries = {
                "ffi",
            },
            incdirs = {
                "$(LIBFFI_INCDIR)",
            },
            libdirs = {
                "$(LIBFFI_LIBDIR)",
            },
            configh = {
                cc = "$(CC)",
                output = "src/config.h",
                incdirs = {
                    "$(LIBFFI_INCDIR)",
                },
                decls = {
                    ['ffi.h'] = {
                        'FFI_OK',
                        'FFI_BAD_TYPEDEF',
                        'FFI_BAD_ABI',
                        'FFI_BAD_ARGTYPE',
                    },
                },
            },
        },
    },
}

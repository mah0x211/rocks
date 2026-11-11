rockspec_format = "3.0"
package = "sync"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-sync.git",
}
description = {
    summary = "lua-sync provides basic synchronization primitives",
    homepage = "https://github.com/mah0x211/lua-sync",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "lauxhlib >= 0.5.0",
}
build_dependencies = {
    "luarocks-build-hooks >= 0.8.0",
}
build = {
    type = "hooks",
    before_build = "$(extra-vars)",
    extra_variables = {
        CFLAGS = "-Wall -Wno-trigraphs -Wmissing-field-initializers -Wreturn-type -Wmissing-braces -Wparentheses -Wno-switch -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow -Wsign-compare",
    },
    conditional_variables = {
        SYNC_COVERAGE = {
            CFLAGS = "--coverage",
            LIBFLAG = "--coverage",
        },
    },
    platforms = {
        linux = {
            ["sync.semaphore"] = {
                libraries = {
                    "pthread",
                    "rt",
                },
            },
        },
        macosx = {
            modules = {
                ["sync.semaphore"] = {
                    libraries = {
                        "pthread",
                    },
                },
            },
        },
    },
    modules = {
        ["sync.semaphore"] = {
            sources = {
                "src/semaphore.c",
            },
            incdirs = {
                "$(DEP_LAUXHLIB_INCDIR)",
            },
        },
        ["sync.mutex"] = {
            sources = {
                "src/mutex.c",
            },
            incdirs = {
                "$(DEP_LAUXHLIB_INCDIR)",
            },
            libraries = {
                "pthread",
            },
        },
        ["sync.cond"] = {
            sources = {
                "src/cond.c",
            },
            incdirs = {
                "$(DEP_LAUXHLIB_INCDIR)",
            },
        },
    },
}

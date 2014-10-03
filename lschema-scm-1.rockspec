package = "lschema"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-lschema.git"
}
description = {
    summary = "lua data schema module",
    homepage = "https://github.com/mah0x211/lua-lschema", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "lrexlib-oniguruma",
    "util",
    "halo",
    "tsukuyomi"
}
build = {
    type = "builtin",
    modules = {
        lschema = "lschema.lua",
        ['lschema.unchangeable'] = "lib/unchangeable.lua",
        ['lschema.aux'] = "lib/aux.lua",
        ['lschema.container'] = "lib/container.lua",
        ['lschema.ddl.errno'] = "lib/ddl/errno.lua",
        ['lschema.ddl.template'] = "lib/ddl/template.lua",
        ['lschema.ddl.enum'] = "lib/ddl/enum.lua",
        ['lschema.ddl.pattern'] = "lib/ddl/pattern.lua",
        ['lschema.ddl.isa'] = "lib/ddl/isa.lua",
        ['lschema.ddl.struct'] = "lib/ddl/struct.lua"
    }
}


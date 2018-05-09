package = "lschema"
version = "1.6.0-1"
source = {
    url = "git://github.com/mah0x211/lua-lschema.git",
    tag = "v1.6.0"
}
description = {
    summary = "lua data schema module",
    homepage = "https://github.com/mah0x211/lua-lschema",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "dump >= 0.1.1",
    "halo >= 1.1.7",
    "isa >= 0.1.0",
    "loadchunk >= 0.1.0",
    "regex >= 0.1.0",
    "string-split >= 0.2.0",
    "tsukuyomi >= 1.1.0",
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
        ['lschema.ddl.struct'] = "lib/ddl/struct.lua",
        ['lschema.ddl.dict'] = "lib/ddl/dict.lua"
    }
}


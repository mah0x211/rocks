package = "dataspec"
version = "dev-1"
source = {
    url = "git+https://github.com/mah0x211/lua-dataspec.git",
}
description = {
    summary = "A data definition and validation module for Lua.",
    homepage = "https://github.com/mah0x211/lua-dataspec",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "error >= 0.13.0",
    "lauxhlib >= 0.6.1",
    "metamodule >= 0.5.0",
}
build = {
    type = "builtin",
    modules = {
        ['dataspec.enum'] = "lib/enum.lua",
        ['dataspec.identifier'] = "lib/identifier.lua",
        ['dataspec.unchangeable'] = "lib/unchangeable.lua",
    },
}


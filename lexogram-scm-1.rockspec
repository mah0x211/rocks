rockspec_format = "3.0"
package = "lexogram"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lexogram.git",
}
description = {
    summary = "grammar-driven lexical and syntactic analyzer that emits a lossless event array.",
    homepage = "https://github.com/mah0x211/lexogram",
    license = "MIT",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        ["lexogram"] = "lua/lexogram.lua",
        ["lexogram.compat"] = "lua/lexogram/compat.lua",
    },
}

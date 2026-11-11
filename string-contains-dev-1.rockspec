package = "string-contains"
version = "dev-1"
source = {
   url = "git+https://github.com/mah0x211/lua-string-contains.git"
}
description = {
   summary = "tests whether a substring is contained in a string or not.",
   homepage = "https://github.com/mah0x211/lua-string-contains",
   license = "MIT",
   maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
       ["string.contains"] = "contains.lua",
   }
}

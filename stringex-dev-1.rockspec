rockspec_format = "3.0"
package = "stringex"
version = "dev-1"
source = {
   url = "git+https://github.com/mah0x211/lua-stringex.git"
}
description = {
   summary = "additional features to the string module.",
   homepage = "https://github.com/mah0x211/lua-stringex",
   license = "MIT"
}
dependencies = {
    "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
       stringex = 'stringex.lua',
       ['stringex.capitalize'] = {
           sources = { 'src/capitalize.c' },
       },
       ['stringex.has'] = 'lib/has.lua',
       ['stringex.split'] = 'lib/split.lua',
       ['stringex.trim'] = 'lib/trim.lua',
   }
}

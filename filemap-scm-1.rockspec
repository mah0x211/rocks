package = "filemap"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-filemap.git"
}
description = {
    summary = "filemap",
    detailed = [[]],
    homepage = "https://github.com/mah0x211/lua-filemap", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        filemap = {
            sources = { 
                "filemap.c"
            }
        }
    }
}


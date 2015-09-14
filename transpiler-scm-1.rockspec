package = "transpiler"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-transpiler.git"
}
description = {
    summary = "url transpiler",
    homepage = "https://github.com/mah0x211/lua-transpiler",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo >= 1.1.7"
}
build = {
    type = "builtin",
    modules = {
        transpiler = "transpiler.lua"
    }
}

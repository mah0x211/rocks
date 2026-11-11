package = "strie2c"
version = "dev-1"
source = {
    url = "git+https://github.com/mah0x211/lua-strie2c.git",
}
description = {
    summary = "Static Trie to C code generator",
    detailed = [[`strie2c` generates optimized C code for string matching using a static trie (prefix tree) compiled into hierarchical switch-case statements. Achieves 1.6-1.9x faster performance than gperf for typical use cases.]],
    homepage = "https://github.com/mah0x211/lua-strie2c",
    maintainer = "Masatoshi Fukunaga",
    license = "MIT",
}
dependencies = {
    "lua >= 5.1",
}
build = {
    type = "builtin",
    modules = {
        strie2c = "lib/strie2c.lua",
    },
}

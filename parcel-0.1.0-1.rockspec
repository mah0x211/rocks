package = "parcel"
version = "0.1.0-1"
source = {
    url = "git+https://github.com/mah0x211/lua-parcel.git",
    tag = "v0.1.0"
}
description = {
    summary = "binary serialization module",
    homepage = "https://github.com/mah0x211/lua-parcel",
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        parcel = {
            sources = { 
                "src/pack.c",
                "src/unpack.c",
                "src/stream_pack.c",
            }
        }
    }
}



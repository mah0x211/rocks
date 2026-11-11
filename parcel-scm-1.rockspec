package = "parcel"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-parcel.git"
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



package = "digitalocean"
version = "0.2.0-1"
source = {
    url = "git://github.com/mah0x211/lua-digitalocean.git",
    tag = "v0.2.0"
}
description = {
    summary = "digitalocean client module",
    homepage = "https://github.com/mah0x211/lua-digitalocean", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo >= 1.1.2"
}
build = {
    type = "builtin",
    modules = {
        digitalocean                    = "digitalocean.lua",
        ['digitalocean.unchangeable']   = 'lib/unchangeable.lua',
        ["digitalocean.api"]            = "api/api.lua",
        ["digitalocean.api.account"]    = "api/account.lua",
        ["digitalocean.api.actions"]    = "api/actions.lua",
        ["digitalocean.api.domains"]    = "api/domains.lua",
        ["digitalocean.api.droplets"]   = "api/droplets.lua",
        ["digitalocean.api.images"]     = "api/images.lua",
        ["digitalocean.api.keys"]       = "api/keys.lua",
        ["digitalocean.api.regions"]    = "api/regions.lua",
        ["digitalocean.api.sizes"]      = "api/sizes.lua"
    }
}


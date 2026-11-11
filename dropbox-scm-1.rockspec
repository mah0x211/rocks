package = "dropbox"
version = "scm-1"
source = {
    url = "git://github.com/mah0x211/lua-dropbox.git"
}
description = {
    summary = "dropbox client module",
    homepage = "https://github.com/mah0x211/lua-dropbox", 
    license = "MIT/X11",
    maintainer = "Masatoshi Teruya"
}
dependencies = {
    "lua >= 5.1",
    "halo >= 1.1.2",
    "path >= 1.0.1"
}
build = {
    type = "builtin",
    modules = {
        dropbox                         = "dropbox.lua",
        ['dropbox.unchangeable']        = 'lib/unchangeable.lua',
        ['dropbox.util']                = 'lib/util.lua',
        ["dropbox.api"]                 = "api/api.lua",
        ["dropbox.api.account"]         = "api/account.lua",
        ["dropbox.api.common"]          = "api/common.lua",
        ["dropbox.api.delta"]           = "api/delta.lua",
        ["dropbox.api.file"]            = "api/file.lua",
        ["dropbox.api.fileops"]         = "api/fileops.lua",
        ["dropbox.api.files"]           = "api/files.lua",
        ["dropbox.api.folder"]          = "api/folder.lua",
        ["dropbox.api.revision"]        = "api/revision.lua",
        ["dropbox.api.sharedFolders"]   = "api/shared_folders.lua"
    }
}


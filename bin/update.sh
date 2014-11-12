#!/bin/sh

set -e
# set -x

function printUsage() {
    echo "Usage: update.sh </path/of/repository> <add|del> </path/of/rockspec/file>" 1>&2
    exit 1
}

CMD_DIR=$(cd "$(dirname $0)"; pwd)
ROCKS_ADMIN=`which luarocks-admin`
LUA=`which lua`
MAKEZIP=$CMD_DIR/makeZip.lua

# check path of repository
if ! [ -d "$1" ]; then
    echo "repository $1 not found."
    printUsage
fi
REPO=$(cd $1; pwd)


function updateManifest() {
    local spec=$1
    local msg=$2
    echo "update repository $REPO"
    # create manifest
    $ROCKS_ADMIN make_manifest .
    # zip manifest files
    $LUA $MAKEZIP

    git add index.html manifest* $spec
    git commit -m "$msg"
    git rebase master gh-pages
}


function addSpec() {
    local specpath=$1
    local spec=$(basename $1)
    local msg
    
    if ! [ -f "$spec" ]; then
        msg="$spec has been added."
    else
        msg="$spec has been updated."
    fi
    
    if ! [ -f "$specpath" ]; then
        echo "rockspec $specpath not found."
        printUsage
    fi
    specpath="$(cd $(dirname $specpath); pwd)/$spec"
    
    cd $REPO
    git checkout master
    cp $specpath ./
    updateManifest $spec "$msg"
}


function delSpec() {
    local spec=$(basename $1)
    
    if ! [ -f "$spec" ]; then
        echo "rockspec $spec not found."
        printUsage
    fi
    
    git checkout master
    git rm $spec
    updateManifest $spec "$spec has been removed"
}


case $2 in
    "add" ) addSpec $3 ;;
    "del" ) delSpec $3 ;;
    * ) echo "command undefined."
        printUsage ;;
esac


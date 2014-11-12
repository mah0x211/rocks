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
    local msg=$1
    echo "update repository $REPO"
    # create manifest
    $ROCKS_ADMIN make_manifest .
    # zip manifest files
    $LUA $MAKEZIP

    git add index.html manifest* $SPEC
    git commit -m "$msg"
    git rebase master gh-pages
}


function addSpec() {
    local specpath=$1
    local spec=$(basename $1)
    
    if ! [ -f "$specpath" ]; then
        echo "rockspec $specpath not found."
        printUsage
    fi
    SPEC_FILE="$(cd $(dirname $specpath); pwd)/$spec"
    
    cd $REPO
    git checkout master
    cp $SPEC_FILE ./
    updateManifest "$spec has been added"
}


function delSpec() {
    local spec=$(basename $1)
    
    if ! [ -f "$spec" ]; then
        echo "rockspec $spec not found."
        printUsage
    fi
    git checkout master
    rm $spec
    updateManifest "$spec has been removed"
}

case $2 in
    "add" ) addSpec $3 ;;
    "del" ) delSpec $3 ;;
    * ) echo "command undefined."
        printUsage ;;
esac


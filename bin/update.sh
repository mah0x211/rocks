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
    local spec=$2

    echo "update repository $REPO"
    # create manifest
    $ROCKS_ADMIN make_manifest .
    # zip manifest files
    $LUA $MAKEZIP

    git add index.html manifest* $spec
    git commit -m "$msg"
    git rebase gh-pages
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
    git checkout gh-pages
    cp $specpath ./
    updateManifest "$msg" $spec
}


function delSpec() {
    local spec=$(basename $1)

    if ! [ -f "$spec" ]; then
        echo "rockspec $spec not found."
        printUsage
    fi

    git checkout gh-pages
    git rm $spec
    updateManifest "$spec has been removed"
}


case $2 in
    "add" ) addSpec $3 ;;
    "del" ) delSpec $3 ;;
    * ) echo "command undefined."
        printUsage ;;
esac


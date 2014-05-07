#!/bin/sh

set -e
set -x

CMD_DIR=$(cd "$(dirname $0)"; pwd)
ROCKS_ADMIN=`which luarocks-admin`
LUA=`which lua`
MAKEZIP=$CMD_DIR/makeZip.lua

if ! [ -d "$1" ]; then
    echo "repository $1 not found."
    exit 1;
elif ! [ -f "$2" ]; then
    echo "rockspec $2 not found."
    exit 1;
fi

REPO=$(cd $1; pwd)
SPEC=$(basename $2)
SPEC_FILE="$(cd $(dirname $2); pwd)/$SPEC"

cd $REPO
cp $SPEC_FILE ./ 

echo "update repository $REPO"
# create manifest
$ROCKS_ADMIN make_manifest .
# zip manifest files
$LUA $MAKEZIP

git checkout master
git add index.html manifest* $SPEC
git commit -m "add $SPEC"

#!/bin/sh

if ! [ -d "$1" ]; then
    echo "repository $1 not found."
    exit 1;
fi

set -e
set -x


ROCKS_ADMIN=`which luarocks-admin`
LUA=`which lua`
CMD_DIR=$(cd "$(dirname $0)"; pwd)
MAKEZIP=$CMD_DIR/makeZip.lua

REPO=$(cd $1; pwd)
echo "update repository $REPO"
cd $REPO
# create manifest
$ROCKS_ADMIN make_manifest .
# zip manifest files
$LUA $MAKEZIP

echo "DONE"
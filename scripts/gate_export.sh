#!/usr/bin/env bash
# Gates

# [[file:code.org::*Gates][Gates:1]]
# Convenience functions for pretty printing messages
RED='\033[0;31m'; ORANGE='\033[0;33m'; GREEN='\033[0;32m'; NC='\033[0m' # No Color
MSG_OK() { echo -e "${GREEN}${@}${NC}"; }
MSG_WARN() { echo -e "${ORANGE}WARNING: ${@}${NC}"; }
MSG_ERR() { echo -e "${RED}ERROR: ${@}${NC}" >&2; }
export GRASS_VERBOSE=3
# export GRASS_MESSAGE_FORMAT=silent
#export PROJ_LIB=/usr/bin/proj
#export DATADIR=/data #/mnt/netapp/glaciologi/MFID_ESA_CCI/data
if [ -z ${DATADIR+x} ]; then
    echo "DATADIR environment varible is unset."
    echo "Fix with: \"export DATADIR=/path/to/data\""
    exit 255
fi

set -x # print commands to STDOUT before running them
g.mapset gates_150_10000

v.out.ogr input=gates_final output=./out/gates.kml format=KML --o
v.out.ogr input=gates_final output=./out/gates.gpkg format=GPKG --o
# Gates:1 ends here

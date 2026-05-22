#!/usr/bin/env bash
# Algorithm
# + [X] Find all fast-moving ice (>X m yr^{-1})
#   + Results not very sensitive to velocity limit (10 to 100 m yr^{-1} examined)
# + [X] Find grounding line by finding edge cells where fast-moving ice borders water or ice shelf based (loosely) on BedMachine mask
# + [X] Move grounding line cells inland by X km, again limiting to regions of fast ice.
#   + Results not very sensitive to gate position (1 - 5 km range examined)

# + [X] Discard gates if group size \in [1,2]
# + [X] Manually clean a few areas (e.g. land-terminating glaciers, gates due to invalid masks, etc.) by manually selecting invalid regions in Google Earth, then remove gates in these regions

# Note that "fast ice" refers to flow velocity, not the sea ice term of "stuck to the land".

# INSTRUCTIONS: Set VELOCITY_CUTOFF and BUFFER_DIST to 50 and 2500 respectively and run the code. Then repeat for a range of other velocity cutoffs and buffer distances to get a range of sensitivities.

# OR: Tangle via ((org-babel-tangle) the code below (C-c C-v C-t or ) to [[./gate_IO.sh]] and then run this in a GRASS session:1


# [[file:code.org::*Algorithm][Algorithm:1]]
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

# 1000: clean results, but too few
# 500: clean results, still too few
# 250: looks good, but 15 Gt < Mankoff 2019. Maybe missing some outlets?
# 150:
VELOCITY_CUTOFF=150
BUFFER_DIST=10000
. "$(dirname "${BASH_SOURCE[0]}")/gate_IO.sh"
# Algorithm:1 ends here

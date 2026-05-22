#!/usr/bin/env bash
# Effective Velocity
# :PROPERTIES:
# :header-args:bash+: :tangle vel_eff.sh
# :END:


# [[file:code.org::*Effective Velocity][Effective Velocity:1]]
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
# Effective Velocity:1 ends here

# ENVEO

# [[file:code.org::*ENVEO][ENVEO:1]]
g.mapsets -l

r.mask -r

MAPSET=$(g.mapsets --q -l separator=newline| grep "gates_")

g.mapset ENVEO
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o
VX=$(g.list type=raster pattern=vx_????_??_?? | head -n1) # DEBUG
for VX in $(g.list type=raster pattern=vx_????_??_??); do
  VY=${VX/vx/vy}
  ERR=${VX/vx/err}
  DATE=$(echo $VX | cut -d"_" -f2-)
  echo $DATE
  r.mapcalc "vel_eff_${DATE} = 365 * (if(gates_x@${MAPSET} == 1, if(isnull(${VX}), 0, abs(${VX}))) + if(gates_y@${MAPSET}, if(isnull(${VY}), 0, abs(${VY}))))"
  r.mapcalc "err_eff_${DATE} = 365 * ${ERR} * (not(isnull(gates_x@${MAPSET})) || not(isnull(gates_y@${MAPSET})))"
  r.null map=vel_eff_${DATE} null=0
  r.null map=err_eff_${DATE} null=0
done

# fix return code of this script so make continues
MSG_OK "vel_eff DONE"
# ENVEO:1 ends here

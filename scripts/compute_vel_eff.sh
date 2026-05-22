#!/usr/bin/env bash
# Computes effective velocity (vel_eff) and effective error (err_eff) at each
# gate pixel for every ENVEO timestep. Units: m yr-1.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

g.mapsets -l

r.mask -r

MAPSET=$(g.mapsets --q -l separator=newline | grep "gates_")

g.mapset ENVEO
g.region -d
r.mapcalc "MASK = if((gates_x@${MAPSET} == 1) | (gates_y@${MAPSET} == 1), 1, null())" --o

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

MSG_OK "vel_eff DONE"

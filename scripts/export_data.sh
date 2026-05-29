#!/usr/bin/env bash
# Exports all gate-masked raster data to tmp/dat.csv for use by Python scripts.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

MSG_OK "Exporting..."
g.mapset PERMANENT
g.region -dp

MAPSET=$(g.mapsets --q -l separator="\n"| grep "gates_")

VEL_baseline="vel_baseline@ENVEO vx_baseline@ENVEO vy_baseline@ENVEO vel_err_baseline@ENVEO err_baseline@ENVEO"
VEL_ENVEO=$(g.list -m mapset=ENVEO type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_ENVEO=$(g.list -m mapset=ENVEO type=raster pattern=err_eff_????_??_?? separator=space)
THICK=$(g.list -m mapset=DEM type=raster pattern="DEM_????" separator=space)

LIST="lon lat err_2D gates_x@${MAPSET} gates_y@${MAPSET} gates_gateID@${MAPSET} sectors@Zwally_2012 sectors@Mouginot_2019 regions@Mouginot_2019 bed@BedMachine thickness@BedMachine surface@BedMachine ${THICK} ${VEL_baseline} ${VEL_ENVEO} errbed@BedMachine ${ERR_ENVEO}"

mkdir -p tmp/dat
r.mapcalc "MASK = if(gates_final@${MAPSET}) | if(mask_GIC@Mouginot_2019) | if(vel_err_baseline@ENVEO) | if(DEM_2020@PRODEM)" --o
parallel --bar "if [[ ! -e ./tmp/dat/{1}.bsv ]]; then (echo x\|y\|{1}; r.out.xyz input={1}) > ./tmp/dat/{1}.bsv; fi" ::: ${LIST}
r.mask -r

# Combine individual per-variable files into one CSV
cat ./tmp/dat/lat.bsv | cut -d"|" -f1,2 | datamash -t"|" transpose > ./tmp/dat_t.bsv
for f in ./tmp/dat/*; do
  cat $f | cut -d"|" -f3 | datamash -t"|" transpose >> ./tmp/dat_t.bsv
done
cat ./tmp/dat_t.bsv | datamash -t"|" transpose | tr '|' ',' > ./tmp/dat.csv

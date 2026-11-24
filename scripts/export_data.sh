#!/usr/bin/env bash
# Exports all gate-masked raster data for use by the Python scripts.
#   export_data.sh            -> tmp/dat.csv          velocity from ENVEO (CCI IV)
#   export_data.sh promice    -> tmp/dat_promice.csv  velocity from PROMICE IV v5
# Both share everything but the time-varying velocity (vel_eff, err_eff): gates,
# thickness, DEMs and the ENVEO baseline. The per-raster files in tmp/dat/ are
# shared and only written once.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

VEL_MAPSET=${1:-ENVEO}
if [ "${VEL_MAPSET}" = "ENVEO" ]; then DAT=./tmp/dat.csv; else DAT=./tmp/dat_${VEL_MAPSET}.csv; fi

MSG_OK "Exporting..."
g.mapset PERMANENT
g.region -dp

MAPSET=$(g.mapsets --q -l separator="\n"| grep "gates_")

VEL_baseline="vel_baseline@ENVEO vx_baseline@ENVEO vy_baseline@ENVEO vel_err_baseline@ENVEO err_baseline@ENVEO"
VEL_EFF=$(g.list -m mapset=${VEL_MAPSET} type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_EFF=$(g.list -m mapset=${VEL_MAPSET} type=raster pattern=err_eff_????_??_?? separator=space)
[ -n "${VEL_EFF}" ] || { MSG_ERR "no vel_eff rasters in mapset ${VEL_MAPSET}"; exit 1; }
THICK=$(g.list -m mapset=DEM type=raster pattern="DEM_????_??" separator=space)

LIST="lon lat err_2D gates_x@${MAPSET} gates_y@${MAPSET} gates_gateID@${MAPSET} sectors@Zwally_2012 sectors@Mouginot_2019 regions@Mouginot_2019 bed@BedMachine thickness@BedMachine surface@BedMachine ${THICK} ${VEL_baseline} ${VEL_EFF} errbed@BedMachine ${ERR_EFF}"

mkdir -p tmp/dat
r.mapcalc "MASK = if(gates_final@${MAPSET}) | if(mask_GIC@Mouginot_2019) | if(vel_err_baseline@ENVEO) | if(DEM_2020@PRODEM)" --o
parallel --bar "if [[ ! -e ./tmp/dat/{1}.bsv ]]; then (echo x\|y\|{1}; r.out.xyz input={1}) > ./tmp/dat/{1}.bsv; fi" ::: ${LIST}
r.mask -r

# Combine this source's per-variable files into one CSV (only those in LIST,
# so the other source's velocity columns stay out)
# r.out.xyz skips null cells, so a raster with nulls inside the MASK would shift
# its column against the others: refuse rather than misalign.
NROW=$(wc -l < ./tmp/dat/lat.bsv)
for v in ${LIST}; do
  n=$(wc -l < ./tmp/dat/${v}.bsv)
  [ "$n" -eq "$NROW" ] || { MSG_ERR "tmp/dat/${v}.bsv has $n rows, lat.bsv has $NROW"; exit 1; }
done
TMP_T=${DAT%.csv}_t.bsv
cat ./tmp/dat/lat.bsv | cut -d"|" -f1,2 | datamash -t"|" transpose > ${TMP_T}
for v in ${LIST}; do
  cat ./tmp/dat/${v}.bsv | cut -d"|" -f3 | datamash -t"|" transpose >> ${TMP_T}
done
cat ${TMP_T} | datamash -t"|" transpose | tr '|' ',' > ${DAT}

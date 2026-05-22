#!/usr/bin/env bash
# Export all data to CSV
# :PROPERTIES:
# :header-args:bash+: :tangle export.sh
# :END:


# [[file:code.org::*Export all data to CSV][Export all data to CSV:1]]
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
# Export all data to CSV:1 ends here


# #+RESULTS:


# [[file:code.org::*Export all data to CSV][Export all data to CSV:2]]
MSG_OK "Exporting..."
g.mapset PERMANENT
g.region -dp

MAPSET=$(g.mapsets --q -l separator="\n"| grep "gates_")

VEL_baseline="vel_baseline@ENVEO vx_baseline@ENVEO vy_baseline@ENVEO vel_err_baseline@ENVEO err_baseline@ENVEO"
VEL_ENVEO=$(g.list -m mapset=ENVEO type=raster pattern=vel_eff_????_??_?? separator=space)
ERR_ENVEO=$(g.list -m mapset=ENVEO type=raster pattern=err_eff_????_??_?? separator=space)
#VEL_Sentinel=$(g.list -m mapset=Sentinel1 type=raster pattern=vel_eff_????_??_?? separator=space)
#ERR_Sentinel=$(g.list -m mapset=Sentinel1 type=raster pattern=err_eff_????_??_?? separator=space)
THICK=$(g.list -m mapset=DEM type=raster pattern=DEM_???? separator=space)
#THICK=$(g.list -m mapset=SEC type=raster pattern=dh_???? separator=space)
# GIMP_0715=dem@GIMP.0715,day@GIMP.0715 # ,err@GIMP.0715

LIST="lon lat err_2D gates_x@${MAPSET} gates_y@${MAPSET} gates_gateID@${MAPSET} sectors@Zwally_2012 sectors@Mouginot_2019 regions@Mouginot_2019 bed@BedMachine thickness@BedMachine surface@BedMachine ${THICK} ${VEL_baseline} ${VEL_ENVEO} errbed@BedMachine ${ERR_ENVEO}"

# ,${VEL_Sentinel},${ERR_Sentinel}

#r.mask gates_final@${MAPSET} --o
mkdir tmp/dat
r.mapcalc "MASK = if(gates_final@${MAPSET}) | if(mask_GIC@Mouginot_2019) | if(vel_err_baseline@ENVEO) | if(DEM_2020@DEM)" --o
parallel --bar "if [[ ! -e ./tmp/dat/{1}.bsv ]]; then (echo x\|y\|{1}; r.out.xyz input={1}) > ./tmp/dat/{1}.bsv; fi" ::: ${LIST}
r.mask -r
# test
# for v in $(echo $LIST | tr ',' '\n'); do n=$(r.univar $v|grep "^n:"); echo ${v}: ${n}; done

# combine individual files to one mega csv
cat ./tmp/dat/lat.bsv | cut -d"|" -f1,2 | datamash -t"|" transpose > ./tmp/dat_t.bsv
for f in ./tmp/dat/*; do
  cat $f | cut -d"|" -f3 | datamash -t"|" transpose >> ./tmp/dat_t.bsv
done
cat ./tmp/dat_t.bsv |datamash -t"|" transpose | tr '|' ',' > ./tmp/dat.csv
#rm ./tmp/dat_t.bsv

#date
#MSG_WARN "Exporting: $(echo $LIST|tr ',' '\n' |wc -l) columns"
#ulimit -n 2048
#time (echo x,y,${LIST}; r.out.xyz input=${LIST} separator=comma) > ./tmp/dat.csv
#r.mask -r
# Export all data to CSV:2 ends here

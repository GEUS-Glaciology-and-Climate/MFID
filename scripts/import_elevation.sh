#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

MSG_OK "PRODEM"
g.mapset -c PRODEM
r.mask -r

for f in $(ls ${DATADIR}/PRODEM/PRODEM??.tif); do
  y=20$(echo ${f: -6:2})
  r.in.gdal -r input=${f} output=DEM_${y} band=1
done
g.region raster=DEM_2019 -pa

MSG_OK "DEM (monthly, integrated from PRODEM July 2020 anchor using dSEC)"
g.mapset -c DEM
g.region raster=DEM_2020@PRODEM -pa

# Anchor: PRODEM represents July, so DEM_2020_07 is our single reference point
r.mapcalc "DEM_2020_07 = DEM_2020@PRODEM" --o

# Get all dSEC maps in chronological order
mapfile -t DSEC_MAPS < <(g.list type=raster mapset=dSEC pattern="SEC_*" separator=newline | LC_ALL=C sort)

# Find the July 2020 dSEC map (anchor for forward integration)
# Map names use underscores (not hyphens) since GRASS forbids hyphens: SEC_2020_07_*
ANCHOR_IDX=-1
for i in "${!DSEC_MAPS[@]}"; do
    [[ "${DSEC_MAPS[$i]}" == SEC_2020_07* ]] && ANCHOR_IDX=$i && break
done
ANCHOR_SEC="${DSEC_MAPS[$ANCHOR_IDX]}"
MSG_OK "dSEC anchor: ${ANCHOR_SEC} (index ${ANCHOR_IDX})"

# Helper: extract start date from map name (e.g. SEC_2020_07_01_... -> 2020-07-01)
dsec_date() {
    echo "$1" | grep -oP '\d{4}_\d{2}_\d{2}' | head -1 | tr '_' '-'
}

# dSEC is cumulative elevation change relative to a reference epoch, so each
# monthly DEM is computed directly from the anchor:
#   DEM(t) = DEM_2020_07 + ( dSEC(t) - dSEC_anchor )
# Nulls in dSEC treated as no change from anchor at that pixel.
for (( i=0; i<${#DSEC_MAPS[@]}; i++ )); do
    SEC="${DSEC_MAPS[$i]}"
    T0=$(dsec_date "${SEC}")
    DEM_NAME="DEM_$(date -d "${T0}" +%Y_%m)"
    r.mapcalc "${DEM_NAME} = DEM_2020_07 + if(isnull(${SEC}@dSEC), 0, ${SEC}@dSEC) - if(isnull(${ANCHOR_SEC}@dSEC), 0, ${ANCHOR_SEC}@dSEC)" --o
done

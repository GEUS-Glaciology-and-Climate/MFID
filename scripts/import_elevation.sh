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
ANCHOR_IDX=-1
for i in "${!DSEC_MAPS[@]}"; do
    [[ "${DSEC_MAPS[$i]}" == SEC_2020-07* ]] && ANCHOR_IDX=$i && break
done
MSG_OK "dSEC anchor index: ${ANCHOR_IDX} (${DSEC_MAPS[$ANCHOR_IDX]})"

# Backward integration: June 2020 → January 2011
# DEM(month) = DEM(month+1) - dSEC(month); nulls in dSEC treated as no change
PREV_DEM="DEM_2020_07"
for (( i=ANCHOR_IDX-1; i>=0; i-- )); do
    SEC="${DSEC_MAPS[$i]}"
    T0=$(echo "${SEC}" | grep -oP '\d{4}-\d{2}-\d{2}' | head -1)
    DEM_NAME="DEM_$(date -d "${T0}" +%Y_%m)"
    r.mapcalc "${DEM_NAME} = ${PREV_DEM} - if(isnull(${SEC}@dSEC), 0, ${SEC}@dSEC)" --o
    PREV_DEM="${DEM_NAME}"
done

# Forward integration: August 2020 → March 2025
# DEM(month+1) = DEM(month) + dSEC(month); nulls in dSEC treated as no change
PREV_DEM="DEM_2020_07"
for (( i=ANCHOR_IDX; i<${#DSEC_MAPS[@]}; i++ )); do
    SEC="${DSEC_MAPS[$i]}"
    T0=$(echo "${SEC}" | grep -oP '\d{4}-\d{2}-\d{2}' | head -1)
    DEM_NAME="DEM_$(date -d "${T0} + 1 month" +%Y_%m)"
    r.mapcalc "${DEM_NAME} = ${PREV_DEM} + if(isnull(${SEC}@dSEC), 0, ${SEC}@dSEC)" --o
    PREV_DEM="${DEM_NAME}"
done

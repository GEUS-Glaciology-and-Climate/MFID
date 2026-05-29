#!/usr/bin/env bash
# Imports CCI SEC (surface elevation change rate) product.
# Data source: http://products.esa-icesheets-cci.org/
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

MSG_OK "SEC"
g.mapset -c SEC

INFILE=${DATADIR}/SEC/permuted/CCI_GrIS_RA_SEC_5km_Vers3.0_2024-05-31_permuted.nc

ls ${INFILE}
ncdump -chs ${INFILE}
ncdump -v x ${INFILE}
ncdump -v y ${INFILE}

g.region w=-741801.6 e=883198.4 s=-3480641.0 n=-410640.7 res=5000 -pa

# Time is encoded as hours since 1990-01-01 in Start_time and End_time.
# Extract start and end years for each of the 28 bands.
REF="1990-01-01"
mapfile -t START_HOURS < <(ncdump -v Start_time "${INFILE}" | sed -n '/^data:/,${p}' | grep -oP '[0-9]+')
mapfile -t END_HOURS   < <(ncdump -v End_time   "${INFILE}" | sed -n '/^data:/,${p}' | grep -oP '[0-9]+')

for ((i=0; i<${#START_HOURS[@]}; i++)); do
    START_YEAR=$(date -d "${REF} + ${START_HOURS[$i]} hours" +%Y)
    END_YEAR=$(date -d "${REF} + ${END_HOURS[$i]} hours" +%Y)
    OUTFILE=SEC_${START_YEAR}_${END_YEAR}
    echo "${OUTFILE}"
    # GDAL bands are 1-indexed; the permuted file has t as the first dimension
    r.external -o source=NetCDF:${INFILE}:SEC band=$((i+1)) output=${OUTFILE}
    r.region -c map=${OUTFILE}
done

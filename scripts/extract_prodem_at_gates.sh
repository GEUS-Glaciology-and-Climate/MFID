#!/usr/bin/env bash
# Extracts PRODEM annual DEM values at gate pixel locations.
# Reads gate x,y from tmp/dat/gates_gateID@gates_150_10000.bsv (already exported).
# Output: tmp/prodem_at_gates.csv  (x,y,gate,DEM_2019,...,DEM_2024)

set -e

GATES_BSV=/home/user/tmp/dat/gates_gateID@gates_150_10000.bsv
OUT=/home/user/tmp/prodem_at_gates.csv
PRODEM_DIR=/data/PRODEM
YEARS="2019 2020 2021 2022 2023 2024"
TMPDIR=/home/user/tmp/prodem_tmp
mkdir -p ${TMPDIR}

echo "Extracting gate coordinates..."
# BSV format: x|y|gate  (skip header)
tail -n +2 ${GATES_BSV} | awk -F'|' '{print $1" "$2}' > ${TMPDIR}/coords_xy.txt
tail -n +2 ${GATES_BSV} | awk -F'|' '{print $1","$2","$3}' > ${TMPDIR}/gate_xyz.csv
echo "$(wc -l < ${TMPDIR}/coords_xy.txt) gate pixels"

echo "Sampling PRODEM rasters..."
for year in ${YEARS}; do
    short=${year: -2}
    tif="${PRODEM_DIR}/PRODEM${short}.tif"
    echo "  PRODEM${short}.tif -> vals_${year}.txt"
    gdallocationinfo -l_srs EPSG:3413 -geoloc -valonly -b 1 "${tif}" \
        < ${TMPDIR}/coords_xy.txt \
        > ${TMPDIR}/vals_${year}.txt
done

echo "Assembling CSV..."
echo "x,y,gate,$(echo $YEARS | tr ' ' ',')" > ${OUT}
paste -d',' \
    ${TMPDIR}/gate_xyz.csv \
    $(for y in ${YEARS}; do echo ${TMPDIR}/vals_${y}.txt; done) \
    >> ${OUT}

echo "Done: $(wc -l < ${OUT}) rows in ${OUT}"

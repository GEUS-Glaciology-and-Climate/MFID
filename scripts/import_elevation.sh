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

MSG_OK "DEM (annual, step-integrated from PRODEM July 2020 anchor using SEC rates)"
g.mapset -c DEM
g.region raster=DEM_2020@PRODEM -pa

# Anchor: PRODEM represents July, so DEM_2020 is our single reference point
r.mapcalc "DEM_2020 = DEM_2020@PRODEM" --o

# List all SEC maps and compute midpoint year for each: SEC_YYYY1_YYYY2 -> mid=(YYYY1+YYYY2)/2
mapfile -t SEC_MAPS < <(g.list type=raster mapset=SEC pattern="SEC_*" separator=newline | LC_ALL=C sort)

declare -A MID_TO_MAP
for map in "${SEC_MAPS[@]}"; do
    Y1=$(echo "$map" | grep -oP '\d{4}' | head -1)
    Y2=$(echo "$map" | grep -oP '\d{4}' | tail -1)
    MID=$(( (Y1 + Y2) / 2 ))
    MID_TO_MAP[$MID]=$map
done

# Find the SEC map whose midpoint year is closest to a given target year
closest_sec_map() {
    local TARGET=$1
    local best_map=""
    local best_dist=9999
    for mid in "${!MID_TO_MAP[@]}"; do
        local dist=$(( mid - TARGET ))
        [[ $dist -lt 0 ]] && dist=$(( -dist ))
        if (( dist < best_dist )); then
            best_dist=$dist
            best_map="${MID_TO_MAP[$mid]}"
        fi
    done
    echo "$best_map"
}

# Forward integration: 2020 -> 2023
# DEM(Y) = DEM(Y-1) + SEC_rate_closest_to_Y * 1 year
# Nulls in SEC treated as no change from the previous year at that pixel.
PREV="DEM_2020"
for Y in 2021 2022 2023; do
    MAP=$(closest_sec_map $Y)
    MSG_OK "DEM_${Y}: adding ${MAP}"
    r.mapcalc "DEM_${Y} = ${PREV} + if(isnull(${MAP}@SEC), 0, ${MAP}@SEC)" --o
    PREV="DEM_${Y}"
done

# Backward integration: 2020 -> 1993
# DEM(Y) = DEM(Y+1) - SEC_rate_closest_to_Y * 1 year
PREV="DEM_2020"
for Y in $(seq 2019 -1 1993); do
    MAP=$(closest_sec_map $Y)
    MSG_OK "DEM_${Y}: subtracting ${MAP}"
    r.mapcalc "DEM_${Y} = ${PREV} - if(isnull(${MAP}@SEC), 0, ${MAP}@SEC)" --o
    PREV="DEM_${Y}"
done

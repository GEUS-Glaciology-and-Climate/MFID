#!/usr/bin/env bash
# PROMICE IV v5 (Sentinel-1, 200 m, ~12-day cadence) into the GRASS mapset
# "promice", as the alternative to the ENVEO/CCI IV in import_velocity.sh.
#
# Only the time-varying velocity is taken from PROMICE: gates, the baseline
# velocity and thickness stay ENVEO-based, so out_promice/ differs from out/
# by the velocity product alone.
#
# Adapted from the PROMICE solid ice discharge workflow
# (ice_discharge/scripts/import_promice.sh). Unlike that script, ey is read
# from the northing error (it reads the easting error twice), and the total
# error err = sqrt(ex^2 + ey^2) is computed as for ENVEO.
#
# Input: $DATADIR/Promice200m_v5/*.nc. Units as ENVEO (m/day);
# compute_vel_eff.sh converts to m/yr.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

MSG_OK "PROMICE IV v5 velocity"
g.mapset -c promice
ROOT=${DATADIR}/Promice200m_v5

EAST=land_ice_surface_easting_velocity
NORTH=land_ice_surface_northing_velocity

FILES=$(find ${ROOT} -name "*.nc" | LC_ALL=C sort)
[ -n "${FILES}" ] || { MSG_ERR "no PROMICE IV files in ${ROOT}"; exit 1; }

for FILE in ${FILES}; do
  DATE_STR=$(ncdump -t -v time ${FILE} | tail -n2 | tr -dc '[0-9\-]' | tr '-' '_')
  echo $DATE_STR

  VARS=$(gdalinfo ${FILE} | grep -o 'NetCDF:"[^"]*":[A-Za-z_]*' | cut -d: -f3)
  for V in ${EAST} ${NORTH} ${EAST}_std ${NORTH}_std; do
    echo "${VARS}" | grep -qx "${V}" || { MSG_ERR "${FILE} has no variable ${V}"; exit 1; }
  done

  r.external -o source="NetCDF:${FILE}:${EAST}"      output=vx_${DATE_STR} --o
  r.external -o source="NetCDF:${FILE}:${NORTH}"     output=vy_${DATE_STR} --o
  r.external -o source="NetCDF:${FILE}:${EAST}_std"  output=ex_${DATE_STR} --o
  r.external -o source="NetCDF:${FILE}:${NORTH}_std" output=ey_${DATE_STR} --o
  r.mapcalc "err_${DATE_STR} = (ex_${DATE_STR}^2 + ey_${DATE_STR}^2)^0.5" --o
done

MSG_OK "PROMICE IV DONE"

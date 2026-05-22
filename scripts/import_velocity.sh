#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

MSG_OK "ENVEO velocity"
g.mapset -c ENVEO
ROOT=${DATADIR}/ENVEO/monthly

for FILE in $(find ${ROOT} -name "greenland*.nc" | LC_ALL=C sort); do
  T=$(echo ${FILE}|grep -o _s........_| tr -dc [0-9])
  DATE_STR=${T:0:4}_${T:4:2}_${T:6:2}
  echo $DATE_STR

  r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity" output=vx_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_velocity" output=vy_${DATE_STR}

  r.external -o source="NetCDF:${FILE}:land_ice_surface_velocity_stddev" output=err_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_stddev" output=ex_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_stddev" output=ey_${DATE_STR}
  r.mapcalc "err_${DATE_STR} = (ex_${DATE_STR}^2 + ey_${DATE_STR}^2)^0.5"
done

for FILE in $(find ${ROOT} -name "*CCI*.nc" | LC_ALL=C sort); do
  T=$(basename "${FILE}" | grep -o '^[0-9]\{8\}')
  DATE_STR=${T:0:4}_${T:4:2}_${T:6:2}
  echo $DATE_STR

  r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_velocity" output=vx_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_velocity" output=vy_${DATE_STR}

  r.external -o source="NetCDF:${FILE}:land_ice_surface_velocity_stddev" output=err_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_easting_stddev" output=ex_${DATE_STR}
  r.external -o source="NetCDF:${FILE}:land_ice_surface_northing_stddev" output=ey_${DATE_STR}
  r.mapcalc "err_${DATE_STR} = (ex_${DATE_STR}^2 + ey_${DATE_STR}^2)^0.5"
done

r.series input=$(g.list type=raster pattern=vx_2018_* separator=",") output=vx_baseline method=average --o
r.series input=$(g.list type=raster pattern=vy_2018_* separator=",") output=vy_baseline method=average --o
r.mapcalc "vel_baseline = 365 * sqrt(vx_baseline^2 + vy_baseline^2) * mask_ice@BedMachine" --o

r.series input=$(g.list type=raster pattern=err_2018_* separator=",") output=err_baseline method=average --o
r.mapcalc "vel_err_baseline = 365 * err_baseline * mask_ice@BedMachine" --o

# Fill holes in velocity data (holes create false gates)
r.mask -r
r.mapcalc "no_vel = if(isnull(vel_baseline), 1, null())"
r.mask no_vel
r.clump input=no_vel output=no_vel_clump --o
ocean_clump=$(r.stats -c -n no_vel_clump sort=desc | head -n1 | cut -d" " -f1)
r.mask -i raster=no_vel_clump maskcats=${ocean_clump} --o
r.fillnulls input=vel_baseline out=vel_baseline_filled method=bilinear
r.mask -r
g.rename raster=vel_baseline_filled,vel_baseline --o
r.colors map=vel_baseline -e color=viridis

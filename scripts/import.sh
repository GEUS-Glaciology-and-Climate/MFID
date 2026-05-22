#!/usr/bin/env bash
# Import Data
# :PROPERTIES:
# :header-args:bash+: :tangle import.sh
# :END:


# [[file:code.org::*Import Data][Import Data:1]]
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
# Import Data:1 ends here

# BedMachine v5
# + from [[textcite:Morlighem:2017BedMachine][Morlighem /et al./ (2017)]]

# [[file:code.org::*BedMachine v5][BedMachine v5:1]]
MSG_OK "BedMachine"
g.mapset -c BedMachine

#for var in $(echo mask surface thickness bed errbed); do
#  echo $var
#  r.external source=netCDF:${DATADIR}/Morlighem_2017/BedMachineGreenland-v5.nc:${var} output=${var}
#done

for var in surface thickness bed errbed mask; do
  echo $var
  r.external source="${DATADIR}"/Morlighem_2022/BMv5_3413/${var}.tif output=${var} --o
done
echo $var
#r.external source="${DATADIR}"/Morlighem_2022/BMv5_3413/mask_float.tif output=mask -o --o

r.colors -a map=errbed color=haxby

g.mapset PERMANENT
g.region raster=surface@BedMachine res=200 -a -p
g.region -s
g.mapset BedMachine
g.region -dp

r.colors map=mask color=haxby

r.mapcalc "mask_ice = if(mask == 2, 1, null())"
# BedMachine v5:1 ends here

# Import & Clean

# [[file:code.org::*Import & Clean][Import & Clean:1]]
MSG_OK "Mouginot 2019 sectors"

g.mapset -c Mouginot_2019
v.in.ogr input=${DATADIR}/Mouginot_2019 output=sectors_all
v.extract input=sectors_all where="NAME NOT LIKE '%ICE_CAP%'" output=sectors

db.select table=sectors | head
v.db.addcolumn map=sectors columns="region_name varchar(100)"
db.execute sql="UPDATE sectors SET region_name=SUBREGION1 || \"___\" || NAME"

# v.db.addcolumn map=sectors columns="area DOUBLE PRECISION"
v.to.db map=sectors option=area columns=area units=meters

mkdir -p ./tmp/
# db.select table=sectors > ./tmp/Mouginot_2019.txt

v.to.rast input=sectors output=sectors use=cat label_column=region_name
r.mapcalc "mask_GIC = if(sectors)"

# # regions map
v.to.rast input=sectors output=regions_tmp use=cat label_column=SUBREGION1
# which categories exist?
# r.category regions separator=comma | cut -d, -f2 | sort | uniq
# Convert categories to numbers
r.category regions_tmp separator=comma | sed s/NO/1/ | sed s/NE/2/ | sed s/CE/3/ | sed s/SE/4/ | sed s/SW/5/ | sed s/CW/6/ | sed s/NW/7/ > ./tmp/mouginot.cat
r.category regions_tmp separator=comma rules=./tmp/mouginot.cat
# r.category regions_tmp
r.mapcalc "regions = @regions_tmp"

# # region vector 
# r.to.vect input=regions output=regions type=area
# v.db.addcolumn map=regions column="REGION varchar(2)"
# v.what.vect map=regions column=REGION query_map=sectors query_column=SUBREGION1

# # mask
# Import & Clean:1 ends here

# Import & Clean

# [[file:code.org::*Import & Clean][Import & Clean:1]]
MSG_OK "Zwally 2012 expanded sectors"

g.mapset -c Zwally_2012
v.in.ogr input=${DATADIR}/Zwally_2012/sectors_enlarged output=sectors

db.select table=sectors | head
v.to.rast input=sectors output=sectors use=cat label_column=cat_
r.mapcalc "mask_GIC = if(sectors)"
# Import & Clean:1 ends here

# 2D Area Error
# + EPSG:3413 has projection errors of \(\pm\) ~8% in Greenland
# + Method
#   + Email: [[mu4e:msgid:m2tvxmd2xr.fsf@gmail.com][Re: {GRASS-user} scale error for each pixel]]
#   + Webmail: https://www.mail-archive.com/grass-user@lists.osgeo.org/msg35005.html

# [[file:code.org::*2D Area Error][2D Area Error:1]]
MSG_OK "2D Area Error"
g.mapset PERMANENT

if [[ "" == $(g.list type=raster pattern=err_2D) ]]; then
    r.mask -r
    g.region -d

    g.region res=1000 -ap # do things faster
    r.mapcalc "x = x()" 
    r.mapcalc "y = y()" 
    r.latlong input=x output=lat_low 
    r.latlong -l input=x output=lon_low 

    r.out.xyz input=lon_low,lat_low separator=space > ./tmp/llxy.txt
    PROJSTR=$(g.proj -j)
    echo $PROJSTR

    paste -d" " <(cut -d" " -f1,2 ./tmp/llxy.txt) <(cut -d" " -f3,4 ./tmp/llxy.txt | proj -VS ${PROJSTR} | grep Areal | column -t | sed s/\ \ /,/g | cut -d, -f4) > ./tmp/xy_err.txt

    r.in.xyz input=./tmp/xy_err.txt  output=err_2D_inv separator=space --overwrite
    r.mapcalc "err_2D = 1/(err_2D_inv^0.5)" # convert area error to linear multiplier error
    g.region -d

    r.latlong input=x output=lat # for exporting at full res
    r.latlong -l input=x output=lon
fi

# sayav done
g.region -d
# 2D Area Error:1 ends here

# Import data
# + Read in all the data
# + Convert from [m day-1] to [m year-1]

# [[file:code.org::*Import data][Import data:1]]
MSG_OK "ENVEO"
g.mapset -c ENVEO
ROOT=${DATADIR}/ENVEO/monthly

find ${ROOT} -name "*.nc"
# FILE=$(find ${ROOT} -name "*.nc"|head -n1) # testing

FILE=$(find ${ROOT} -name "greenland*.nc" | head -n1) # DEBUG
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

FILE=$(find ${ROOT} -name "*CCI*.nc" | head -n1) # DEBUG
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
# Import data:1 ends here

# Find baseline

# [[file:code.org::*Find baseline][Find baseline:1]]
r.series input=$(g.list type=raster pattern=vx_2018_* separator=",") output=vx_baseline method=average --o
r.series input=$(g.list type=raster pattern=vy_2018_* separator=",") output=vy_baseline method=average --o
r.mapcalc "vel_baseline = 365 * sqrt(vx_baseline^2 + vy_baseline^2) * mask_ice@BedMachine" --o

r.series input=$(g.list type=raster pattern=err_2018_* separator=",") output=err_baseline method=average --o
r.mapcalc "vel_err_baseline = 365 * err_baseline * mask_ice@BedMachine" --o
# Find baseline:1 ends here

# Fill in holes
# + There are holes in the velocity data which will create false gates. Fill them in.
# + Clump based on yes/no velocity
#   + Largest clump is GIS
#   + 2nd largest is ocean
# + Mask by ocean (so velocity w/ holes remains)
# + Fill holes

# [[file:code.org::*Fill in holes][Fill in holes:1]]
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
# Fill in holes:1 ends here

# Bjørk 2015
# + Write out x,y,name. Can use x,y and mean gate location to find closest name for each gate.

# [[file:code.org::*Bjørk 2015][Bjørk 2015:1]]
MSG_OK "Bjørk 2015"
g.mapset -c Bjork_2015

ROOT=${DATADIR}/Bjork_2015/

cat ${ROOT}/GreenlandGlacierNames_GGNv01.csv |  iconv -c -f utf-8 -t ascii | grep GrIS | awk -F';' '{print $3"|"$2"|"$7}' | sed s/,/./g | m.proj -i input=- | sed s/0.00\ //g | v.in.ascii input=- output=names columns="x double precision, y double precision, name varchar(99)"

# db.select table=names | tr '|' ',' > ./tmp/Bjork_2015_names.csv
# Bjørk 2015:1 ends here

# Mouginot 2019

# [[file:code.org::*Mouginot 2019][Mouginot 2019:1]]
g.mapset Mouginot_2019
db.select table=sectors | head
# v.out.ascii -c input=sectors output=./tmp/Mouginot_2019_names.csv columns=NAME,SUBREGION1
# Mouginot 2019:1 ends here

# PRODEM


# [[file:code.org::*PRODEM][PRODEM:1]]
MSG_OK "dh/dt"

g.mapset -c PRODEM
r.mask -r

f=$(ls ${DATADIR}/PRODEM/PRODEM??.tif | head -n1) # debug
for f in $(ls ${DATADIR}/PRODEM/PRODEM??.tif); do
  y=20$(echo ${f: -6:2})
  r.in.gdal -r input=${f} output=DEM_${y} band=1
  # r.in.gdal -r input=${f} output=var_${y} band=2
  # r.in.gdal -r input=${f} output=dh_${y} band=3
  # r.in.gdal -r input=${f} output=time_${y} band=4
  # r.univar -g time_2019 # mean = DOI 213 = 01 Aug
done
g.region raster=DEM_2019 -pa
# PRODEM:1 ends here

# SEC

# Using CCI SEC data from citet:simonsen_2017_implications,sørensen_2015_envisat,khvorostovsky_2012_merging,CCI_SEC.

# + This NetCDF file is malformed and needs some dimensions swapped before GDAL can read it.
# + Thanks: https://stackoverflow.com/questions/47642695/how-can-i-swap-the-dimensions-of-a-netcdf-file


# [[file:code.org::*SEC][SEC:1]]
g.mapset -c SEC

ls ${DATADIR}/SEC/CCI_GrIS_RA_SEC_5km_Vers3.0_2024-05-31.nc
INFILE=${DATADIR}/SEC/CCI_GrIS_RA_SEC_5km_Vers3.0_2024-05-31.nc
ncdump -chs ${INFILE}
ncdump -v x ${INFILE}
ncdump -v y ${INFILE}

g.region w=-739301.625 e=880698.375 s=-3478140.75 n=-413140.75 res=5000 -p
g.region w=w-2500 e=e+2500 n=n+2500 s=s-2500 -pa

ncap2 --overwrite -s 'SEC2=SEC.permute($t,$y,$x)' ${INFILE} ./tmp/SEC.nc
INFILE=./tmp/SEC.nc

# ncdump -p 9,5 ./tmp/SEC.nc |less
for i in $(seq 28); do
  d0=$(( ${i}+1991 ))-01-01
  d1=$(( ${i}+1996 ))-01-01
  n0=$(echo $d0 | sed s/-//g)
  n1=$(echo $d1 | sed s/-//g)
  OUTFILE=SEC_${n0}_${n1}
  echo $OUTFILE
  r.external -o source=NetCDF:${INFILE}:SEC2 band=${i} output=${OUTFILE}
  r.region -c map=${OUTFILE}
done
# SEC:1 ends here

# Define annual values

# [[file:code.org::*Define annual values][Define annual values:1]]
r.mapcalc "dh_2014 = SEC_20120101_20170101"
r.mapcalc "dh_2015 = SEC_20130101_20180101"
r.mapcalc "dh_2016 = SEC_20140101_20190101"
r.mapcalc "dh_2017 = SEC_20150101_20200101"
r.mapcalc "dh_2018 = SEC_20160101_20210101"
r.mapcalc "dh_2019 = SEC_20170101_20220101"


seq 2014 2019 | parallel --bar --progress "r.null map=dh_{} null=0" --quiet
# Define annual values:1 ends here

# DEM

# + Merge Khan dh/dt w/ PRODEM to generate annual DEMs


# [[file:code.org::*DEM][DEM:1]]
MSG_OK "DEM"
g.mapset -c DEM

g.region raster=DEM_2020@PRODEM -pa

for y in {2019..2023}; do
  r.mapcalc "DEM_${y} = DEM_${y}@PRODEM"
done

for y in {2019..2014}; do
  y1=$(( ${y} + 1 ))
  r.mapcalc "DEM_${y} = DEM_${y1} - dh_${y}@SEC"
done
# DEM:1 ends here

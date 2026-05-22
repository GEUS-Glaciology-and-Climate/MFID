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

MSG_OK "SEC"
g.mapset -c SEC

ls ${DATADIR}/SEC/CCI_GrIS_RA_SEC_5km_Vers3.0_2024-05-31.nc
INFILE=${DATADIR}/SEC/CCI_GrIS_RA_SEC_5km_Vers3.0_2024-05-31.nc
ncdump -chs ${INFILE}

g.region w=-739301.625 e=880698.375 s=-3478140.75 n=-413140.75 res=5000 -p
g.region w=w-2500 e=e+2500 n=n+2500 s=s-2500 -pa

# SEC NetCDF has swapped dimensions; permute before reading
ncap2 --overwrite -s 'SEC2=SEC.permute($t,$y,$x)' ${INFILE} ./tmp/SEC.nc
INFILE=./tmp/SEC.nc

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

r.mapcalc "dh_2014 = SEC_20120101_20170101"
r.mapcalc "dh_2015 = SEC_20130101_20180101"
r.mapcalc "dh_2016 = SEC_20140101_20190101"
r.mapcalc "dh_2017 = SEC_20150101_20200101"
r.mapcalc "dh_2018 = SEC_20160101_20210101"
r.mapcalc "dh_2019 = SEC_20170101_20220101"

seq 2014 2019 | parallel --bar --progress "r.null map=dh_{} null=0" --quiet

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

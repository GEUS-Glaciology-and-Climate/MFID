#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

MSG_OK "BedMachine"
g.mapset -c BedMachine

for var in surface thickness bed errbed mask; do
  echo $var
  r.external source="${DATADIR}"/Morlighem_2022/BMv5_3413/${var}.tif output=${var} --o
done

r.colors -a map=errbed color=haxby

g.mapset PERMANENT
g.region raster=surface@BedMachine res=200 -a -p
g.region -s
g.mapset BedMachine
g.region -dp

r.colors map=mask color=haxby

r.mapcalc "mask_ice = if(mask == 2, 1, null())"

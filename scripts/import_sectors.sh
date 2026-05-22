#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

MSG_OK "Mouginot 2019 sectors"
g.mapset -c Mouginot_2019
v.in.ogr input=${DATADIR}/Mouginot_2019 output=sectors_all
v.extract input=sectors_all where="NAME NOT LIKE '%ICE_CAP%'" output=sectors

db.select table=sectors | head
v.db.addcolumn map=sectors columns="region_name varchar(100)"
db.execute sql="UPDATE sectors SET region_name=SUBREGION1 || \"___\" || NAME"

v.to.db map=sectors option=area columns=area units=meters

mkdir -p ./tmp/

v.to.rast input=sectors output=sectors use=cat label_column=region_name
r.mapcalc "mask_GIC = if(sectors)"

v.to.rast input=sectors output=regions_tmp use=cat label_column=SUBREGION1
r.category regions_tmp separator=comma | sed s/NO/1/ | sed s/NE/2/ | sed s/CE/3/ | sed s/SE/4/ | sed s/SW/5/ | sed s/CW/6/ | sed s/NW/7/ > ./tmp/mouginot.cat
r.category regions_tmp separator=comma rules=./tmp/mouginot.cat
r.mapcalc "regions = @regions_tmp"

MSG_OK "Zwally 2012 expanded sectors"
g.mapset -c Zwally_2012
v.in.ogr input=${DATADIR}/Zwally_2012/sectors_enlarged output=sectors

db.select table=sectors | head
v.to.rast input=sectors output=sectors use=cat label_column=cat_
r.mapcalc "mask_GIC = if(sectors)"

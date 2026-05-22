#!/usr/bin/env bash
# Adds metadata to the gates_final vector:
#   gate ID, mean x/y coordinates, lon/lat, sector, region, glacier names
# Exports out/gate_meta.csv and tmp/gates_final_<cutoff>_<dist>.kml
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

VELOCITY_CUTOFF=150
BUFFER_DIST=10000

g.mapset gates_${VELOCITY_CUTOFF}_${BUFFER_DIST}

# Gate ID: convert raster clusters to vector polygons
r.to.vect input=gates_final output=gates_final type=area --o
v.db.dropcolumn map=gates_final column=label
v.db.dropcolumn map=gates_final column=value
v.db.addcolumn map=gates_final columns="gate INT"
v.what.rast map=gates_final raster=gates_gateID column=gate type=centroid

# Mean x,y coordinates per gate
v.db.addcolumn map=gates_final columns="mean_x INT, mean_y INT"
v.to.db map=gates_final option=coor columns=x,y units=meters
v.to.db map=gates_final option=area columns=area units=meters

for G in $(db.select -c sql="select gate from gates_final"|sort -n|uniq); do
  db.execute sql="UPDATE gates_final SET mean_x=(SELECT AVG(x) FROM gates_final WHERE gate == ${G}) where gate == ${G}"
  db.execute sql="UPDATE gates_final SET mean_y=(SELECT AVG(y) FROM gates_final WHERE gate == ${G}) where gate == ${G}"
done

# Point layer at mean gate location (used for attribute lookup)
v.out.ascii -c input=gates_final columns=gate,mean_x,mean_y | cut -d"|" -f4- | sort -n|uniq | v.in.ascii input=- output=gates_final_pts skip=1 cat=1 x=2 y=3 --o
v.db.addtable gates_final_pts
v.db.addcolumn map=gates_final_pts columns="gate INT"
v.db.update map=gates_final_pts column=gate query_column=cat
v.to.db map=gates_final_pts option=coor columns=mean_x,mean_y units=meters

# Mean lon,lat
v.what.rast map=gates_final_pts raster=lon@PERMANENT column=lon
v.what.rast map=gates_final_pts raster=lat@PERMANENT column=lat

v.db.addcolumn map=gates_final columns="mean_lon DOUBLE PRECISION, mean_lat DOUBLE PRECISION"
for G in $(db.select -c sql="select gate from gates_final"|sort -n|uniq); do
    db.execute sql="UPDATE gates_final SET mean_lon=(SELECT lon FROM gates_final_pts WHERE gate = ${G}) where gate = ${G}"
    db.execute sql="UPDATE gates_final SET mean_lat=(SELECT lat FROM gates_final_pts WHERE gate = ${G}) where gate = ${G}"
done

# Sector, region, and glacier names
v.db.addcolumn map=gates_final columns="sector INT"
v.db.addcolumn map=gates_final_pts columns="sector INT"
v.distance from=gates_final to=sectors@Mouginot_2019 upload=to_attr column=sector to_column=cat
v.distance from=gates_final_pts to=sectors@Mouginot_2019 upload=to_attr column=sector to_column=cat

v.db.addcolumn map=gates_final columns="region VARCHAR(2)"
v.db.addcolumn map=gates_final_pts columns="region VARCHAR(2)"
v.distance from=gates_final to=sectors@Mouginot_2019 upload=to_attr column=region to_column=SUBREGION1
v.distance from=gates_final_pts to=sectors@Mouginot_2019 upload=to_attr column=region to_column=SUBREGION1

v.db.addcolumn map=gates_final columns="Mouginot_2019 VARCHAR(99)"
v.db.addcolumn map=gates_final_pts columns="Mouginot_2019 VARCHAR(99)"
v.distance from=gates_final to=sectors@Mouginot_2019 upload=to_attr column=Mouginot_2019 to_column=NAME
v.distance from=gates_final_pts to=sectors@Mouginot_2019 upload=to_attr column=Mouginot_2019 to_column=NAME

v.db.addcolumn map=gates_final columns="Bjork_2015 VARCHAR(99)"
v.db.addcolumn map=gates_final_pts columns="Bjork_2015 VARCHAR(99)"
v.distance from=gates_final to=names@Bjork_2015 upload=to_attr column=Bjork_2015 to_column=name
v.distance from=gates_final_pts to=names@Bjork_2015 upload=to_attr column=Bjork_2015 to_column=name

v.db.addcolumn map=gates_final columns="n_pixels INT"
v.db.addcolumn map=gates_final_pts columns="n_pixels INT"
for G in $(db.select -c sql="select gate from gates_final"|sort -n|uniq); do
    db.execute sql="UPDATE gates_final SET n_pixels=(SELECT SUM(area)/(200*200) FROM gates_final WHERE gate = ${G}) where gate = ${G}"
    db.execute sql="UPDATE gates_final_pts SET n_pixels = (SELECT n_pixels FROM gates_final WHERE gate = ${G}) WHERE gate = ${G}"
done

db.dropcolumn -f table=gates_final column=area

mkdir -p out
db.select sql="SELECT gate,mean_x,mean_y,lon,lat,n_pixels,sector,region,Bjork_2015,Mouginot_2019 from gates_final_pts" separator=, | sort -n | uniq > ./out/gate_meta.csv

v.out.ogr input=gates_final output=./tmp/gates_final_${VELOCITY_CUTOFF}_${BUFFER_DIST}.kml format=KML --o

#!/usr/bin/env bash
# Finds ice discharge gates by:
#   1. Identifying fast-moving ice (> VELOCITY_CUTOFF m/yr)
#   2. Finding the grounding line edge where fast ice meets ocean/ice shelf
#   3. Moving gates BUFFER_DIST inland
#   4. Cleaning up small clusters and masking to Mouginot 2019 extent
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

# Results not very sensitive to these values (tested 10–100 m/yr and 1–5 km)
VELOCITY_CUTOFF=150
BUFFER_DIST=10000

g.mapset -c gates_${VELOCITY_CUTOFF}_${BUFFER_DIST}
g.region -d

# Buffer BedMachine mask by 2 km so it reaches the edge of velocity data
g.copy raster=mask_ice@BedMachine,mask_ice --o
r.grow input=mask_ice output=mask_ice_grow radius=10 new=1 --o
r.mask mask_ice_grow

r.mapcalc "fast_ice = if(vel_baseline@ENVEO > ${VELOCITY_CUTOFF}, 1, null())" --o
r.mapcalc "fast_ice_100 = if(vel_baseline@ENVEO > 100, 1, null())" --o
r.mask -r

r.mapcalc "not_ice = if(isnull(vel_baseline@ENVEO) ||| (mask@BedMachine == 0) ||| (mask@BedMachine == 3), 1, null())" --o

r.grow input=not_ice output=not_ice_grow radius=1.5 new=99 --o
r.mapcalc "fast_ice_edge = if(((not_ice_grow == 99) && (fast_ice == 1)), 1, null())" --o

r.buffer input=fast_ice_edge output=fast_ice_buffer distances=${BUFFER_DIST} --o
r.grow input=fast_ice_buffer output=fast_ice_buffer_grow radius=1.5 new=99 --o
r.mask -i not_ice --o
r.mapcalc "gates_inside = if(((fast_ice_buffer_grow == 99) && (fast_ice_100 == 1)), 1, null())" --o
r.mask -r

r.grow input=gates_inside output=gates_inside_grow radius=1.1 new=99 --o
r.mask -i not_ice --o
r.mapcalc "gates_maybe = if(((gates_inside_grow == 99) && (fast_ice_100 == 1) && isnull(fast_ice_buffer)), 1, null())" --o
r.mask -r

r.grow input=gates_maybe output=gates_maybe_grow radius=1.1 new=99 --o
r.mask -i not_ice --o
r.mapcalc "gates_outside = if(((gates_maybe_grow == 99) && (fast_ice_100 == 1) && isnull(fast_ice_buffer) && isnull(gates_inside)), 1, null())" --o
r.mask -r

# gates_IO: 1 = inside (discharge flows through), -1 = outside
r.mapcalc "gates_IO = 0" --o
r.mapcalc "gates_IO = if(isnull(gates_inside), gates_IO, 1)" --o
r.mapcalc "gates_IO = if(isnull(gates_outside), gates_IO, -1)" --o

r.colors map=gates_inside color=red
r.colors map=gates_maybe color=grey
r.colors map=gates_outside color=blue
r.colors map=gates_IO color=viridis

# Determine x/y gate components based on flow direction
r.mask -r

r.mapcalc "gates_x = 0" --o
r.mapcalc "gates_x = if((gates_maybe == 1) && (vx_baseline@ENVEO > 0), gates_IO[0,1], gates_x)" --o
r.mapcalc "gates_x = if((gates_maybe != 0) && (vx_baseline@ENVEO < 0), gates_IO[0,-1], gates_x)" --o

r.mapcalc "gates_y = 0" --o
r.mapcalc "gates_y = if((gates_maybe != 0) && (vy_baseline@ENVEO > 0), gates_IO[-1,0], gates_y)" --o
r.mapcalc "gates_y = if((gates_maybe != 0) && (vy_baseline@ENVEO < 0), gates_IO[1,0], gates_y)" --o

r.mapcalc "gates_x = if(gates_x == 1, 1, 0)" --o
r.mapcalc "gates_y = if(gates_y == 1, 1, 0)" --o

r.null map=gates_x null=0
r.null map=gates_y null=0

# Clean step 0: subset to where DEM coverage exists
r.mapcalc "gates_xy_clean00 = if((gates_x == 1) || (gates_y == 1), 1, null())" --o
r.mapcalc "gates_xy_clean0 = if(gates_xy_clean00 & if(DEM_2019@DEM), 1, null())" --o

# Clean step 1: remove clusters of ≤9 pixels (~360 m × 360 m)
r.clump -d input=gates_xy_clean0 output=gates_gateID --o
r.reclass.area -d input=gates_gateID output=gates_area value=9 mode=lesser method=reclass --o
r.mapcalc "gates_xy_clean1 = if(isnull(gates_area), gates_xy_clean0, null())" --o

# Clean step 2: limit to Mouginot 2019 mask (grown by 3 cells to avoid edge clipping)
r.grow input=mask_GIC@Mouginot_2019 output=mask_GIC_Mouginot_2019_grow radius=4.5
r.mask mask_GIC_Mouginot_2019_grow --o
r.mapcalc "gates_xy_clean2 = gates_xy_clean1" --o
r.mask -r

# No manual KML removal applied; using clean2 as final
g.copy "gates_xy_clean2,gates_final" --o

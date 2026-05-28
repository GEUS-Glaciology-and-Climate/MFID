#!/usr/bin/env bash
# Exports gate geometries to out/ as KML and GeoPackage.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

g.mapset gates_150_10000

mkdir -p out
v.out.ogr input=gates_final output=./out/gates.kml format=KML --o
v.out.ogr input=gates_final output=./out/gates.gpkg format=GPKG --o

#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

MSG_OK "Bjørk 2015 glacier names"
g.mapset -c Bjork_2015
ROOT=${DATADIR}/Bjork_2015/
cat ${ROOT}/GreenlandGlacierNames_GGNv01.csv \
  | iconv -c -f utf-8 -t ascii \
  | grep GrIS \
  | awk -F';' '{print $3"|"$2"|"$7}' \
  | sed s/,/./g \
  | m.proj -i input=- \
  | sed s/0.00\ //g \
  | v.in.ascii input=- output=names columns="x double precision, y double precision, name varchar(99)"

MSG_OK "Mouginot 2019 names"
g.mapset Mouginot_2019
db.select table=sectors | head

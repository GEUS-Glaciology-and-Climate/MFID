#!/usr/bin/env bash
# Imports CCI dSEC (differential surface elevation change) product.
# Data source: http://products.esa-icesheets-cci.org/
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

MSG_OK "dSEC"
g.mapset -c dSEC

ls ${DATADIR}/dSEC/CCI_GrIS_RA_dSEC_dh_5km_012011_032025.nc
INFILE=${DATADIR}/dSEC/CCI_GrIS_RA_dSEC_dh_5km_012011_032025.nc
ncdump -chs ${INFILE}
ncdump -v x ${INFILE}
ncdump -v y ${INFILE}

g.region w=-832025.1 e=987974.9 s=-3337070 n=-457070.5 res=5000 -p
g.region w=w-2500 e=e+2500 n=n+2500 s=s-2500 -pa

TIMES=$(ncdump -v time "$INFILE" | sed -n '/time = "/,/;/p' | sed '1s/.*= //;$s/;//' | tr -d '",')

mapfile -t times <<< "$TIMES"

for ((i=0; i<${#times[@]}-1; i++)); do
  t0=${times[i]%%T*}
  next_date=${times[i+1]%%T*}
  t1=$(date -d "$next_date - 1 day" +%F)
  OUTFILE=SEC_${t0}_${t1}
  echo $OUTFILE
  r.external -o source=NetCDF:${INFILE}:ZZ band=${i} output=${OUTFILE}
  r.region -c map=${OUTFILE}
done

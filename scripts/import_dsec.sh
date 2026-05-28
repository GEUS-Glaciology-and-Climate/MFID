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

# Use Python to extract all time steps reliably.
# ncdump wraps 3 values per output line, so the naive mapfile approach reads
# every 3rd monthly band instead of all 171 — hence the Python workaround.
TIMES_FILE=$(mktemp)
python3 -c "
import netCDF4 as nc, sys
ds = nc.Dataset('${INFILE}')
for t in ds.variables['time'][:]:
    print(t[:10])  # YYYY-MM-DD
ds.close()
" > "$TIMES_FILE"

mapfile -t times < "$TIMES_FILE"
rm "$TIMES_FILE"

for ((i=0; i<${#times[@]}-1; i++)); do
  # Replace hyphens with underscores (GRASS map names may not contain hyphens)
  t0=$(echo "${times[i]}" | tr '-' '_')
  t1=$(date -d "${times[i+1]} - 1 day" +%F | tr '-' '_')
  OUTFILE=SEC_${t0}_${t1}
  echo $OUTFILE
  # GDAL bands are 1-indexed; band i+1 corresponds to time step i
  r.external -o source=NetCDF:${INFILE}:ZZ band=$((i+1)) output=${OUTFILE}
  r.region -c map=${OUTFILE}
done

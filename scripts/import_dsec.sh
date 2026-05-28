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

# Extract time steps: ncdump wraps values across lines, so pipe through grep
# to get one YYYY-MM-DD per line regardless of wrapping. Scoped to data: section
# to avoid matching the file_creation_date attribute.
TIMES_FILE=$(mktemp)
ncdump -v time "${INFILE}" | sed -n '/^data:/,${p}' | grep -oP '\d{4}-\d{2}-\d{2}' > "$TIMES_FILE"

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

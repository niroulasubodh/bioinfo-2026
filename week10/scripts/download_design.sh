#!/usr/bin/env bash
set -euo pipefail
BIOPROJECT="${1:?Usage: download_design.sh BIOPROJECT [design.csv]}"
OUTPUT="${2:-design.csv}"
for tool in esearch efetch python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: $tool not installed" >&2; exit 1; }
done
mkdir -p "$(dirname "$OUTPUT")"
TMP=$(mktemp "${OUTPUT}.tmp.XXXXXX")
trap 'rm -f "$TMP"' EXIT
for attempt in 1 2 3; do
  if esearch -db sra -query "$BIOPROJECT" | efetch -format runinfo > "$TMP" && \
    python3 - "$TMP" <<'PYCODE'
import csv, sys
with open(sys.argv[1], newline='') as f:
    rows = list(csv.reader(f))
if len(rows) < 2:
    sys.exit('ERROR: NCBI returned no run metadata')
header = {x.strip().lower() for x in rows[0]}
if 'run' not in header or not ({'sample', 'biosample'} & header):
    sys.exit('ERROR: NCBI response lacks Run and Sample/BioSample columns')
print(f'>> Download contains {len(rows)-1} run records')
PYCODE
  then
    mv "$TMP" "$OUTPUT"
    echo ">> Downloaded $OUTPUT for $BIOPROJECT"
    exit 0
  fi
  echo ">> Download attempt $attempt failed" >&2
  sleep 3
done
echo 'ERROR: unable to download valid metadata; existing design file was not changed' >&2
exit 1

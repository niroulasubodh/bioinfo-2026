#!/usr/bin/env bash
# Invoked by: make design parallel=4 N=4 [DESIGN_CSV=design.csv]
set -euo pipefail
JOBS="${1:-4}"
DESIGN="${2:-design.csv}"
N="${3:-all}"
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo 'ERROR: parallel must be a positive integer' >&2; exit 2; }
[[ "$N" == all || "$N" =~ ^[1-9][0-9]*$ ]] || { echo 'ERROR: N must be a positive integer or all' >&2; exit 2; }
[[ -f "$DESIGN" ]] || { echo "ERROR: design file not found: $DESIGN" >&2; exit 2; }
command -v parallel >/dev/null || { echo 'ERROR: GNU Parallel is missing' >&2; exit 2; }
[[ -f scripts/split_design.py ]] || { echo 'ERROR: scripts/split_design.py is missing' >&2; exit 2; }
mkdir -p design reports
python3 scripts/split_design.py "$DESIGN" design/.all_rows.tsv reports/.all_groups.tsv
TOTAL=$(wc -l < design/.all_rows.tsv | tr -d '[:space:]')
(( TOTAL > 0 )) || { echo 'ERROR: no valid samples' >&2; exit 2; }
if [[ "$N" == all ]] || (( 10#$N >= TOTAL )); then COUNT="$TOTAL"; else COUNT=$((10#$N)); fi
head -n "$COUNT" design/.all_rows.tsv > design/.batch_rows.tsv
head -n "$((COUNT+1))" reports/.all_groups.tsv > reports/sample_groups.tsv
printf '>> Selected %s samples; at most %s concurrent jobs\n' "$COUNT" "$JOBS"
make --no-print-directory prepare-shared
parallel --jobs "$JOBS" --halt soon,fail=1 --joblog reports/parallel_joblog.tsv --colsep '\t' \
  make --no-print-directory single-all 'SRR_ACCESSION={1}' 'SAMPLE_NAME={2}' \
  :::: design/.batch_rows.tsv
printf '>> Completed %s samples. Peak files: peaks/*_peaks.narrowPeak; IGV tracks: tracks/*.bw\n' "$COUNT"

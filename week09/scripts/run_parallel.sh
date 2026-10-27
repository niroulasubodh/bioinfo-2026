
#!/usr/bin/env bash
# Called by: make design parallel=4 N=10
set -euo pipefail

JOBS="${1:-4}"
DESIGN="${2:-design.csv}"
N="${3:-all}"
COVERAGE="${4:-100}"
READ_LEN="${5:-50}"

[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || {
  echo "ERROR: parallel must be a positive integer" >&2
  exit 2
}

[[ "$N" == all || "$N" =~ ^[1-9][0-9]*$ ]] || {
  echo "ERROR: N must be a positive integer or all" >&2
  exit 2
}

[[ -f "$DESIGN" ]] || {
  echo "ERROR: design file not found: $DESIGN" >&2
  exit 2
}

[[ -f scripts/split_design.py ]] || {
  echo "ERROR: scripts/split_design.py is missing" >&2
  exit 2
}

command -v parallel >/dev/null || {
  echo "ERROR: install GNU Parallel" >&2
  exit 2
}

mkdir -p design reports

# Read and validate all samples
python3 scripts/split_design.py \
  "$DESIGN" \
  design/.all_rows.tsv \
  reports/.all_groups.tsv

TOTAL=$(wc -l < design/.all_rows.tsv | tr -d ' ')

(( TOTAL > 0 )) || {
  echo "ERROR: no valid samples" >&2
  exit 2
}

# Select N samples
if [[ "$N" == all ]] || (( N > TOTAL )); then
  COUNT="$TOTAL"
else
  COUNT="$N"
fi

head -n "$COUNT" design/.all_rows.tsv \
  > design/.batch_rows.tsv

head -n "$((COUNT + 1))" reports/.all_groups.tsv \
  > reports/sample_groups.tsv

echo "Selected $COUNT samples; $JOBS parallel jobs"

# Prepare shared reference genome once
make --no-print-directory prepare-shared

# Run independent sample pipelines
parallel --jobs "$JOBS" \
  --halt soon,fail=1 \
  --joblog reports/parallel_joblog.tsv \
  --colsep '\t' \
  make --no-print-directory single-all \
    'SRR_ACCESSION={1}' \
    'SAMPLE_NAME={2}' \
    "COVERAGE=$COVERAGE" \
    "READ_LEN=$READ_LEN" \
  :::: design/.batch_rows.tsv

echo "All $COUNT samples completed."

echo "To merge selected samples, run:"
printf 'make merge annotate coding SAMPLES="'
cut -f2 design/.batch_rows.tsv | paste -sd' ' -
printf '"\n'

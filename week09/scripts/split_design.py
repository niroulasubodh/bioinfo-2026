#!/usr/bin/env python3
"""Parse SRA design CSV, preserve metadata, and write Run/Sample batch rows."""
import csv
import sys

def load(path):
    with open(path, newline='', encoding='utf-8-sig') as f:
        rows = [r for r in csv.reader(f) if any(c.strip() for c in r)]
    if not rows:
        sys.exit('ERROR: design file is empty')
    header, data = rows[0], rows[1:]
    norm = [c.strip().lower() for c in header]
    if 'run' not in norm:
        sys.exit('ERROR: missing Run column')
    if 'sample' not in norm and 'biosample' not in norm:
        sys.exit('ERROR: missing Sample or BioSample column')
    runidx = norm.index('run')
    sampleidx = norm.index('sample' if 'sample' in norm else 'biosample')
    other = [i for i in range(len(header)) if i not in (runidx, sampleidx)]
    result = []
    seen = set()
    for lineno, row in enumerate(data, start=2):
        if len(row) != len(header):
            sys.exit(f'ERROR: CSV row {lineno} contains {len(row)} fields; expected {len(header)}')
        run = row[runidx].strip()
        sample = row[sampleidx].strip()
        if not run or not sample:
            sys.exit(f'ERROR: missing Run or Sample in row {lineno}')
        if sample in seen:
            sys.exit(f'ERROR: duplicate sample {sample!r} in row {lineno}; each Run requires a unique Sample name')
        if any(c.isspace() for c in sample) or any(c.isspace() for c in run):
            sys.exit(f'ERROR: whitespace in Run or Sample at row {lineno}; use safe identifiers')
        seen.add(sample)
        result.append((run, sample, [row[i] for i in other]))
    return header, other, result

def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == '--samples-only':
        _, _, records = load(args[1])
        for _, sample, _ in records:
            print(sample)
        return
    if len(args) != 3:
        sys.exit('Usage: split_design.py [--samples-only design.csv | design.csv batch_rows.tsv sample_groups.tsv]')
    header, other, records = load(args[0])
    with open(args[1], 'w', newline='') as f, open(args[2], 'w', newline='') as g:
        r, m = csv.writer(f, delimiter='\t'), csv.writer(g, delimiter='\t')
        m.writerow(['Sample', 'Run'] + [header[i] for i in other])
        for run, sample, metadata in records:
            r.writerow([run, sample])
            m.writerow([sample, run] + metadata)

if __name__ == '__main__':
    main()

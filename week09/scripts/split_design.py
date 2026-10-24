"""
Parse a design.csv with an arbitrary column set and extract what the
Makefile needs, by COLUMN NAME (case-insensitive), not by position.

Required columns (any name match, case-insensitive): "Run", and either
"Sample" OR "BioSample" (if "Sample" is absent, "BioSample" values are
used as the sample name instead). All other columns (BioProject, Group,
Condition, Mutation, etc.) are optional, may appear in any order/number,
and are preserved verbatim as metadata.

Usage:
  split_design.py <design.csv> <batch_rows_out.tsv> <sample_groups_out.tsv>
      Writes:
        batch_rows_out.tsv    : Run<TAB>Sample   (one line per sample row,
                                 consumed by `make batch`'s xargs fan-out)
        sample_groups_out.tsv : Sample<TAB>Run<TAB>col3<TAB>col4...
                                 (full metadata, header included, for
                                 reports/sample_groups.tsv)

  split_design.py --samples-only <design.csv>
      Prints one Sample name per line (for Makefile $(shell ...) use).
"""
import csv
import sys


def load_rows(path):
    with open(path, newline="") as f:
        text = f.read()
    # Tolerate Windows line endings.
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    reader = csv.reader(text.splitlines())
    rows = [r for r in reader if any(cell.strip() for cell in r)]
    if not rows:
        sys.exit("ERROR: design.csv is empty.")
    header = rows[0]
    data = rows[1:]

    norm = [h.strip().lower() for h in header]
    try:
        run_idx = norm.index("run")
    except ValueError:
        sys.exit('ERROR: design.csv header must include a "Run" column.')
    sample_idx = None
    sample_source = None
    if "sample" in norm:
        sample_idx = norm.index("sample")
        sample_source = "Sample"
    elif "biosample" in norm:
        sample_idx = norm.index("biosample")
        sample_source = "BioSample"
    else:
        sys.exit(
            'ERROR: design.csv header must include a "Sample" or '
            '"BioSample" column.'
        )

    return header, data, run_idx, sample_idx, sample_source


def main():
    args = sys.argv[1:]
    if args and args[0] == "--samples-only":
        header, data, run_idx, sample_idx, _ = load_rows(args[1])
        seen = set()
        for row in data:
            sample = row[sample_idx].strip()
            if sample and sample not in seen:
                seen.add(sample)
                print(sample)
        return

    if len(args) != 3:
        sys.exit(__doc__)

    design_csv, batch_rows_out, sample_groups_out = args
    header, data, run_idx, sample_idx, sample_source = load_rows(design_csv)
    print(f">> Using '{header[sample_idx]}' column as Sample name.", file=sys.stderr)

    seen_samples = {}
    with open(batch_rows_out, "w") as rows_f, open(sample_groups_out, "w") as groups_f:
        other_idx = [i for i in range(len(header)) if i not in (run_idx, sample_idx)]
        groups_f.write(
            "\t".join(["Sample", "Run"] + [header[i] for i in other_idx]) + "\n"
        )
        for row in data:
            run = row[run_idx].strip()
            sample = row[sample_idx].strip()
            if not run or not sample:
                continue
            if sample in seen_samples:
                sys.exit(
                    f"ERROR: duplicate Sample '{sample}' in design.csv "
                    f"(rows with Run={seen_samples[sample]} and Run={run}). "
                    "Sample names must be unique."
                )
            seen_samples[sample] = run
            rows_f.write(f"{run}\t{sample}\n")
            groups_f.write(
                "\t".join([sample, run] + [row[i] if i < len(row) else "" for i in other_idx])
                + "\n"
            )


if __name__ == "__main__":
    main()
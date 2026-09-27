# Generate a BAM File

**Purpose:** This pipeline downloads a reference genome and sequencing reads from SRA, then aligns the reads to produce a sorted, indexed BAM file. All steps are run through a single `Makefile`.

The pipeline is designed for Illumina paired-end short reads (R1 and R2), which are aligned using `bwa mem`.

## Requirements

Make sure these tools are installed and available on your `PATH`:

- `curl`
- [SRA Toolkit](https://github.com/ncbi/sra-tools): `prefetch` and `fasterq-dump`
- [BWA](https://github.com/lh3/bwa)
- [Samtools](https://www.htslib.org/)
- GNU `make`, `bash`, `awk`, `sed`, and `gzip`

## Folder layout

Running the pipeline creates this structure:

```text
.
├── Makefile
├── genome/
│   ├── <ORG_NAME>_genome.fna.gz
│   ├── <ORG_NAME>_genome.fna
│   ├── <ORG_NAME>_genome.fna.{amb,ann,bwt,pac,sa}
│   └── .genome_size
├── fastq/
│   ├── <ORG_NAME>_1.fastq.gz
│   ├── <ORG_NAME>_2.fastq.gz
│   ├── .num_reads
│   └── .config_sig
└── align/
    ├── <ORG_NAME>.bam
    └── <ORG_NAME>.bam.bai
```

The BWA index files are stored in `genome/`. The `.genome_size`, `.num_reads`, and `.config_sig` files store values used by the pipeline. Output filenames use your chosen `ORG_NAME` rather than the accession numbers.

## Configuration

Set these variables at the top of the `Makefile`, or override them on the command line. For example: `make genome ORG_NAME=myvirus`.

| Variable | Description | Default |
| --- | --- | --- |
| `Genome_Accession_Number` | NCBI RefSeq genome accession | `GCF_000850405.1` |
| `Genome_Accession_Name` | Accession name used in the NCBI file path | `ViralMultiSegProj14746` |
| `ORG_NAME` | Label used in output filenames | `orthohantavirus` |
| `SRR_ACCESSION` | SRA run accession for the sequencing reads | `SRR34582745` |
| `COVERAGE` | Target sequencing coverage used to estimate the read count | `10` |
| `READ_LEN` | Average length, in bp, of each read in a pair | `190` |
| `NUM_READS` | Manual override for the number of read pairs | Empty; calculated automatically |

### How the read count is estimated

After downloading the genome, the pipeline calculates its size in base pairs. It estimates the number of read pairs needed for the target coverage as:

```text
read pairs = (genome size in bp × COVERAGE) / (2 × READ_LEN)
```

The factor of 2 accounts for the two reads in each pair. To request a specific number of read pairs instead, run:

```bash
make fastq NUM_READS=5000
```

### Determining `READ_LEN` from your data

`READ_LEN` should reflect the average length of an individual Illumina read. You can estimate it from the *Total Bases* and *Total Sequences* values in a FastQC report for one FASTQ file:

```text
READ_LEN = Total Bases / Total Sequences
```

For example, 1,900,000 total bases across 10,000 sequences gives an average read length of 190 bp.

An inaccurate `READ_LEN` changes the estimated read count and therefore the coverage achieved. You can override its default value at runtime:

```bash
make fastq READ_LEN=190
```

### Detecting changes to coverage and read-length settings

Make normally tracks changes to files, not changes to variables such as `COVERAGE`, `READ_LEN`, and `NUM_READS`. The `fastq` target therefore runs a `check-config` step that compares the current settings with the signature stored in `fastq/.config_sig`.

When the settings change, the pipeline removes the cached read-count estimate in `fastq/.num_reads`. Make can then recalculate the read count and rebuild the downstream FASTQ targets. When the settings are unchanged, it leaves the cached estimate in place.

For example:

```bash
make all COVERAGE=20
```

This detects the new coverage setting without requiring `make clean`.

## Usage

```bash
make genome   # Download and decompress the genome; calculate its size
make fastq    # Estimate the read count; download and rename the FASTQ files
make align    # Index the genome; align reads; sort and index the BAM file
make all      # Run the full pipeline
make clean    # Remove the generated genome/, fastq/, and align/ directories
```

### Run the full pipeline with custom parameters

```bash
make all \
  Genome_Accession_Number=GCF_000850405.1 \
  Genome_Accession_Name=ViralMultiSegProj14746 \
  ORG_NAME=orthohantavirus \
  SRR_ACCESSION=SRR34582745 \
  COVERAGE=15 \
  READ_LEN=190
```

## Notes

- Make's dependency tracking rebuilds targets when their file inputs change.
- The `check-config` step detects changes to `COVERAGE`, `READ_LEN`, and `NUM_READS`.
- `make align` builds the BWA index if it does not already exist.
- `make clean` removes the generated directories but leaves the `Makefile` in place.

## What percentage of reads align?

Run:

```bash
samtools flagstat align/orthohantavirus.bam
```

Output:

```text
2420 + 0 in total (QC-passed reads + QC-failed reads)
2420 + 0 primary
0 + 0 secondary
0 + 0 supplementary
0 + 0 duplicates
0 + 0 primary duplicates
2350 + 0 mapped (97.11% : N/A)
2350 + 0 primary mapped (97.11% : N/A)
2420 + 0 paired in sequencing
1210 + 0 read1
1210 + 0 read2
2344 + 0 properly paired (96.86% : N/A)
2344 + 0 with itself and mate mapped
6 + 0 singletons (0.25% : N/A)
0 + 0 with mate mapped to a different chr
0 + 0 with mate mapped to a different chr (mapQ>=5)
```

**Interpretation:** Of the 2,420 individual reads, 2,350 mapped to the reference genome (97.11%). A total of 2,344 reads were properly paired (96.86% of all reads).

## What do the alignments look like?

![Read alignments and coverage viewed in IGV](IGV/IGV_alignment.png)

**Interpretation:** In the IGV alignment track, gray portions of reads match the reference sequence. Colored bases indicate mismatches, which could represent sequence variation or sequencing errors. Most visible mismatches involve single bases or short stretches. Coverage is uneven: it is highest around 300–600 bp, drops near 600 bp, and varies at lower levels across the rest of the displayed region.
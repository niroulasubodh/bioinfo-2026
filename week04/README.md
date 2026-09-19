# Get FASTQ Files from SRA

**Organisms:** *Orthohantavirus andesense*

**SRR Accession:** [SRR38840885](https://www.ncbi.nlm.nih.gov/sra/SRX33807787[accn])

**About the Dataset:** There are 49 sequencing datasets available in the published scientific literature. These datasets were generated using two platforms: Oxford Nanopore and Illumina. Most of the sequences were generated using Illumina, possibly because this organism has a relatively short genome.

## Download and check a read subset

Install SRA Toolkit (`fastq-dump`), FastQC (`fastqc`), and fastp (`fastp`), then run:

```sh
make all SRR=SRR38840885 N=10000
```

Change only `SRR` to analyze a different SRA run. `N` is the number of **spots**
requested, starting with spot 1. A spot normally contains one read for
single-end sequencing or a pair of reads for paired-end sequencing, so `N=10000`
can produce up to 10,000 reads in each paired FASTQ file. Fewer reads may be
written when a run has fewer spots or filtered technical reads.

The workflow downloads the subset, runs FastQC on the original reads, trims
adapters and low-quality 3′ ends with fastp, and runs FastQC again. Open the
HTML reports from the raw and trimmed FastQC folders to compare the plots.
The fastp HTML report provides trimming statistics as well.

### Trimming settings

The Makefile uses the same fastp options for paired and single reads:

| Option | Value | What it does |
| --- | --- | --- |
| `--cut_tail` | enabled | Trims low-quality bases from the 3′ end. |
| `--cut_window_size` | `4` | Checks quality in windows of four bases. |
| `--cut_mean_quality` | `20` | Trims when a window's mean Phred score is below Q20. |

fastp also uses its default adapter trimming and read filtering settings.
These settings are intended for short reads; review them before using a
long-read run such as Oxford Nanopore.

| Contents | Folder |
| --- | --- |
| Original FASTQ files | `data/raw/<SRR>/N<N>/` |
| Trimmed FASTQ files | `data/trimmed/<SRR>/N<N>/` |
| Original FastQC reports | `reports/fastqc/raw/<SRR>/N<N>/` |
| Trimmed FastQC reports | `reports/fastqc/trimmed/<SRR>/N<N>/` |
| fastp HTML and JSON reports | `reports/fastp/<SRR>/N<N>/` |

Files are named `sample_R1.fastq` and `sample_R2.fastq` for paired reads, and
`sample_single.fastq` for single reads. The accession and subset size in the
folder path identify the run. If a run contains both pairs and singleton reads,
all three files are processed.

You can also run each stage separately with `make download`, `make qc_raw`,
`make trim`, or `make qc_trim`. Pass the same `SRR` and `N` values to each stage.

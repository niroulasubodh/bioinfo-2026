# Use Bash for the validation checks and conditional processing below.
SHELL := /bin/bash

# Choose the SRA run and how many of its first spots to download.
# Override either value, for example: make all SRR=SRR123456 N=10000
SRR ?= SRR38840885
N ?= 10000

# Keep each run and subset size in its own raw-data, trimmed-data, and report folders.
RUN := $(SRR)/N$(N)
RAW := data/raw/$(RUN)
TRIMMED := data/trimmed/$(RUN)
RAW_QC := reports/fastqc/raw/$(RUN)
TRIMMED_QC := reports/fastqc/trimmed/$(RUN)
TRIM_LOG := reports/fastp/$(RUN)

# Expose each workflow stage as a command without creating files named after it.
.PHONY: all download qc_raw trim qc_trim check

# Run the complete workflow or request one stage and its prerequisites.
all: qc_trim
download: $(RAW)/.done
qc_raw: $(RAW_QC)/.done
trim: $(TRIMMED)/.done
qc_trim: $(TRIMMED_QC)/.done

# Reject invalid inputs and report missing command-line tools before downloading.
check:
	@[[ "$(SRR)" =~ ^SRR[0-9]+$$ ]] || { echo 'SRR must be an SRR accession (for example SRR39057280)' >&2; exit 1; }
	@[[ "$(N)" =~ ^0*[1-9][0-9]*$$ ]] || { echo 'N must be a positive whole number' >&2; exit 1; }
	@for tool in fastq-dump fastqc fastp; do command -v "$$tool" >/dev/null || { echo "Missing tool: $$tool" >&2; exit 1; }; done

# Download only the first N spots, then rename paired and single reads.
$(RAW)/.done: | check
	@mkdir -p "$(RAW)"
	fastq-dump --minSpotId 1 --maxSpotId "$(N)" --skip-technical --split-3 --outdir "$(RAW)" "$(SRR)"
	@# Rename the first and second reads of each pair, if present.
	@for number in 1 2; do \
		if [[ -f "$(RAW)/$(SRR)_$${number}.fastq" ]]; then \
			mv "$(RAW)/$(SRR)_$${number}.fastq" "$(RAW)/sample_R$${number}.fastq"; \
		fi; \
	done
	@# Rename unpaired reads, including single-end sequencing runs.
	@if [[ -f "$(RAW)/$(SRR).fastq" ]]; then mv "$(RAW)/$(SRR).fastq" "$(RAW)/sample_single.fastq"; fi
	@# Require a complete pair or at least one single-read file before marking this stage done.
	@[[ -s "$(RAW)/sample_R1.fastq" && -s "$(RAW)/sample_R2.fastq" ]] || \
		[[ ! -e "$(RAW)/sample_R1.fastq" && ! -e "$(RAW)/sample_R2.fastq" && -s "$(RAW)/sample_single.fastq" ]] || \
		{ echo 'Download did not produce a complete read pair or single-read file' >&2; exit 1; }
	@touch "$@"

# Create FastQC HTML and ZIP reports for the original FASTQ files.
$(RAW_QC)/.done: $(RAW)/.done
	@mkdir -p "$(RAW_QC)"
	fastqc --outdir "$(RAW_QC)" "$(RAW)"/*.fastq
	@touch "$@"

# Trim reads with fastp and save its HTML and JSON reports.
$(TRIMMED)/.done: $(RAW_QC)/.done
	@mkdir -p "$(TRIMMED)" "$(TRIM_LOG)"
	@# Keep paired reads synchronized while trimming them.
	@if [[ -s "$(RAW)/sample_R1.fastq" && -s "$(RAW)/sample_R2.fastq" ]]; then \
		fastp --in1 "$(RAW)/sample_R1.fastq" --in2 "$(RAW)/sample_R2.fastq" \
			--out1 "$(TRIMMED)/sample_R1.fastq" --out2 "$(TRIMMED)/sample_R2.fastq" \
			--cut_tail --cut_window_size 4 --cut_mean_quality 20 \
			--html "$(TRIM_LOG)/paired.html" --json "$(TRIM_LOG)/paired.json"; \
	fi
	@# Trim single reads separately, including any unpaired reads from a paired run.
	@if [[ -s "$(RAW)/sample_single.fastq" ]]; then \
		fastp --in1 "$(RAW)/sample_single.fastq" --out1 "$(TRIMMED)/sample_single.fastq" \
			--cut_tail --cut_window_size 4 --cut_mean_quality 20 \
			--html "$(TRIM_LOG)/single.html" --json "$(TRIM_LOG)/single.json"; \
	fi
	@touch "$@"

# Create FastQC HTML and ZIP reports for the trimmed FASTQ files.
$(TRIMMED_QC)/.done: $(TRIMMED)/.done
	@mkdir -p "$(TRIMMED_QC)"
	fastqc --outdir "$(TRIMMED_QC)" "$(TRIMMED)"/*.fastq
	@touch "$@"

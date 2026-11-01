
# ==========================================================
# MOUSE ATAC-SEQ PEAK-CALLING PIPELINE
# Chromosome selection + paired-end read subsampling
# ==========================================================
#
# This pipeline:
# 1. Downloads a shared mouse reference genome.
# 2. Extracts and indexes a selected chromosome.
# 3. Downloads paired-end SRA sequencing reads.
# 4. Subsamples up to MAX_READ_PAIRS using seqtk.
# 5. Aligns reads with BWA-MEM.
# 6. Filters alignments using samtools.
# 7. Calls peaks using MACS3.
# 8. Counts peaks and generates IGV bigWig tracks.
#
# Single sample:
#   make all SRR_ACCESSION=SRR23500889 \
#       CHROMOSOME=chr1 MAX_READ_PAIRS=10000
#
# Multiple samples:
#   make design parallel=1 N=4 \
#       CHROMOSOME=chr1 MAX_READ_PAIRS=10000
#
# Use MAX_READ_PAIRS=all for full-depth analysis.
#
# WARNING:
# Aligning directly to one chromosome can produce
# incorrectly placed reads from other chromosomes.
# This is intended for exploratory analysis.
# ==========================================================

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.NOTPARALLEL:

# Prefer tools installed in the project environment.
TOOLS_DIR ?= $(CURDIR)/.bioinfo-env/bin
export PATH := $(TOOLS_DIR):$(PATH)


# ==========================================================
# 1. REFERENCE GENOME
# ==========================================================

Genome_Accession_Number ?= GCF_000001635.27
Genome_Accession_Name ?= GRCm39
ORG_NAME ?= Mus_musculus

# Select a chromosome: chr1, chr2, ..., chr19, chrX, chrY.
CHROMOSOME ?= chr1

AssemblyPrefix := $(word 1,$(subst _, ,$(Genome_Accession_Number)))
DigitsWithVersion := $(word 2,$(subst _, ,$(Genome_Accession_Number)))
Digits := $(firstword $(subst ., ,$(DigitsWithVersion)))
TripletPath := $(shell echo $(Digits) | sed -E 's/(.{3})(.{3})(.{3})/\1\/\2\/\3/')
AssemblyDir := $(Genome_Accession_Number)_$(Genome_Accession_Name)

Genome_URL := https://ftp.ncbi.nlm.nih.gov/genomes/all/$(AssemblyPrefix)/$(TripletPath)/$(AssemblyDir)/$(AssemblyDir)_genomic.fna.gz


# ==========================================================
# 2. SAMPLE CONFIGURATION
# ==========================================================

BIOPROJECT ?= PRJNA935800
SRR_ACCESSION ?= SRR23500889
SAMPLE_NAME ?= $(SRR_ACCESSION)
DESIGN_CSV ?= design.csv

# Number of samples selected from the design file.
N ?= all

# Maximum number of concurrent sample jobs.
parallel ?= 2

# Threads allocated to each sample.
THREADS ?= 2

# Maximum number of paired-end read PAIRS per sample.
# Use all to disable subsampling.
MAX_READ_PAIRS ?= 10000

# Fixed random seed makes subsampling reproducible.
SUBSAMPLE_SEED ?= 42

# MACS3 peak-calling parameters.
MACS_QVALUE ?= 0.01
MACS_GSIZE ?= auto


# ==========================================================
# 3. DIRECTORIES AND OUTPUT FILES
# ==========================================================

GENOME_DIR := genome
FASTQ_DIR := fastq
ALIGN_DIR := align
PEAK_DIR := peaks
TRACK_DIR := tracks
REPORT_DIR := reports

GENOME_GZ := $(GENOME_DIR)/$(ORG_NAME)_genome.fna.gz
GENOME_FA := $(GENOME_DIR)/$(ORG_NAME)_genome.fna

# Only this chromosome is indexed using BWA.
CHR_GENOME := $(GENOME_DIR)/$(ORG_NAME)_$(CHROMOSOME).fna

# Original FASTQ files are retained unchanged.
FASTQ_R1 := $(FASTQ_DIR)/$(SAMPLE_NAME)_1.fastq.gz
FASTQ_R2 := $(FASTQ_DIR)/$(SAMPLE_NAME)_2.fastq.gz

# Encode read count and seed in output directory names.
# This avoids reusing results from a previous read limit.
READ_TAG := $(if $(filter all,$(MAX_READ_PAIRS)),all,reads$(MAX_READ_PAIRS)_seed$(SUBSAMPLE_SEED))

SAMPLE_SUBSET_DIR := $(FASTQ_DIR)/subsets/$(READ_TAG)

SUBSET_R1 := $(SAMPLE_SUBSET_DIR)/$(SAMPLE_NAME)_1.fastq.gz
SUBSET_R2 := $(SAMPLE_SUBSET_DIR)/$(SAMPLE_NAME)_2.fastq.gz
SUBSET_STAMP := $(SAMPLE_SUBSET_DIR)/$(SAMPLE_NAME).complete

# Choose original or subsampled FASTQs for alignment.
ifeq ($(MAX_READ_PAIRS),all)
  ALIGN_R1 := $(FASTQ_R1)
  ALIGN_R2 := $(FASTQ_R2)
else
  ALIGN_R1 := $(SUBSET_R1)
  ALIGN_R2 := $(SUBSET_R2)
endif

RUN_ALIGN_DIR := $(ALIGN_DIR)/$(CHROMOSOME)/$(READ_TAG)
RUN_PEAK_DIR := $(PEAK_DIR)/$(CHROMOSOME)/$(READ_TAG)
RUN_TRACK_DIR := $(TRACK_DIR)/$(CHROMOSOME)/$(READ_TAG)
RUN_REPORT_DIR := $(REPORT_DIR)/$(CHROMOSOME)/$(READ_TAG)

RAW_BAM := $(RUN_ALIGN_DIR)/$(SAMPLE_NAME).raw.bam
BAM_OUT := $(RUN_ALIGN_DIR)/$(SAMPLE_NAME).bam

PEAK_OUT := $(RUN_PEAK_DIR)/$(SAMPLE_NAME)_peaks.narrowPeak
PEAK_STATS := $(RUN_REPORT_DIR)/$(SAMPLE_NAME)_peak_stats.tsv
BIGWIG_OUT := $(RUN_TRACK_DIR)/$(SAMPLE_NAME).bw


# ==========================================================
# 4. TARGET DECLARATIONS
# ==========================================================

.PHONY: help check-config check-tools genome chromosome \
        prepare-shared download-design design fastq subset \
        align peaks peak-stats tracks single-all all \
        clean print-chromosomes


# ==========================================================
# 5. HELP
# ==========================================================

help:
	@echo "Mouse ATAC-seq peak-calling pipeline"
	@echo ""
	@echo "Single sample:"
	@echo "  make all SRR_ACCESSION=SRR23500889 CHROMOSOME=chr1 MAX_READ_PAIRS=10000"
	@echo ""
	@echo "Multiple samples:"
	@echo "  make design parallel=1 N=4 CHROMOSOME=chr1 MAX_READ_PAIRS=10000"
	@echo ""
	@echo "Use all reads:"
	@echo "  make all MAX_READ_PAIRS=all"
	@echo ""
	@echo "Download sample metadata:"
	@echo "  make download-design BIOPROJECT=PRJNA935800"


# ==========================================================
# 6. VALIDATE SETTINGS AND SOFTWARE
# ==========================================================

# Ensure MAX_READ_PAIRS is a positive integer or 'all'.
check-config:
	@case '$(MAX_READ_PAIRS)' in \
	  all) ;; \
	  *[!0-9]*|'') echo "ERROR: MAX_READ_PAIRS must be positive or all" >&2; exit 2;; \
	  *) if [ '$(MAX_READ_PAIRS)' -le 0 ]; then exit 2; fi;; \
	esac
	@case '$(THREADS)' in \
	  *[!0-9]*|'') echo "ERROR: THREADS must be positive" >&2; exit 2;; \
	  *) test '$(THREADS)' -gt 0;; \
	esac

check-tools: check-config
	@for tool in curl gzip prefetch fasterq-dump bwa samtools macs3 bamCoverage; do \
		command -v "$$tool" >/dev/null 2>&1 || { \
			echo "ERROR: Missing $$tool" >&2; exit 1; \
		}; \
	done
	@if [ "$(MAX_READ_PAIRS)" != all ]; then \
		command -v seqtk >/dev/null 2>&1 || { \
			echo "ERROR: Install seqtk" >&2; exit 1; \
		}; \
	fi


# ==========================================================
# 7. SINGLE-SAMPLE AND MULTI-SAMPLE WORKFLOWS
# ==========================================================

# Process one sample.
all: single-all

single-all: check-tools peaks peak-stats tracks

# Prepare the chromosome reference before starting
# several samples in parallel.
prepare-shared: check-tools $(CHR_GENOME).bwt $(CHR_GENOME).fai

# Download NCBI BioProject run metadata.
download-design:
	@bash scripts/download_design.sh "$(BIOPROJECT)" "$(DESIGN_CSV)"

# Launch the existing GNU Parallel controller.
# Make command-line variables are inherited by recursive Make.
design: check-config
	@CHROMOSOME="$(CHROMOSOME)" \
	  THREADS="$(THREADS)" \
	  MAX_READ_PAIRS="$(MAX_READ_PAIRS)" \
	  SUBSAMPLE_SEED="$(SUBSAMPLE_SEED)" \
	  MACS_QVALUE="$(MACS_QVALUE)" \
	  MACS_GSIZE="$(MACS_GSIZE)" \
	  bash scripts/run_parallel.sh \
	  "$(parallel)" "$(DESIGN_CSV)" "$(N)"


# ==========================================================
# 8. DOWNLOAD REFERENCE GENOME
# ==========================================================

genome: $(GENOME_FA)

$(GENOME_GZ):
	@mkdir -p "$(GENOME_DIR)"
	curl -fL --retry 3 -o "$@" "$(Genome_URL)"

$(GENOME_FA): $(GENOME_GZ)
	gunzip -c "$<" > "$@"

# Create full-reference FASTA index for chromosome extraction.
# This does NOT build the expensive full-genome BWA index.
$(GENOME_FA).fai: $(GENOME_FA)
	samtools faidx "$<"

print-chromosomes: $(GENOME_FA).fai
	@grep '^NC_' "$(GENOME_FA).fai" | cut -f1 | head -n 30


# ==========================================================
# 9. EXTRACT AND INDEX ONE CHROMOSOME
# ==========================================================

chromosome: $(CHR_GENOME)

# Resolve chromosome aliases to mouse GRCm39 NCBI IDs.
# chr1 corresponds to NC_000067.*, chr2 to NC_000068.*.
$(CHR_GENOME): $(GENOME_FA).fai
	@mkdir -p "$(GENOME_DIR)"
	@selected="$$(awk -v c="$(CHROMOSOME)" 'BEGIN { \
		sub(/^chr/, "", c); \
		if (c ~ /^[0-9]+$$/ && c >= 1 && c <= 19) prefix=sprintf("NC_%06d", 66+c); \
		else if (c=="X") prefix="NC_000086"; \
		else if (c=="Y") prefix="NC_000087"; \
		else if (c=="M" || c=="MT") prefix="NC_005089"; \
		else prefix=""; \
	} \
	$$1==c || $$1=="$(CHROMOSOME)" || \
	(prefix!="" && index($$1,prefix ".")==1) {print $$1; exit}' "$(GENOME_FA).fai")"; \
	if [ -z "$$selected" ]; then \
		echo "ERROR: Chromosome not found" >&2; exit 1; \
	fi; \
	echo ">> Extracting $(CHROMOSOME): $$selected"; \
	samtools faidx "$(GENOME_FA)" "$$selected" > "$@"

# Build BWA index only for selected chromosome.
$(CHR_GENOME).bwt: $(CHR_GENOME)
	bwa index "$<"

$(CHR_GENOME).fai: $(CHR_GENOME)
	samtools faidx "$<"


# ==========================================================
# 10. DOWNLOAD ORIGINAL PAIRED-END FASTQ FILES
# ==========================================================
# The original FASTQs are downloaded once.
# Subsampling occurs in a separate step.
# No original reads are deleted by seqtk.

fastq: $(FASTQ_R1) $(FASTQ_R2)

$(FASTQ_R1):
	@mkdir -p "$(FASTQ_DIR)"

	prefetch "$(SRR_ACCESSION)" -O "$(FASTQ_DIR)"

	fasterq-dump \
		--split-files \
		-e "$(THREADS)" \
		-O "$(FASTQ_DIR)" \
		"$(FASTQ_DIR)/$(SRR_ACCESSION)/$(SRR_ACCESSION).sra"

	@test -s "$(FASTQ_DIR)/$(SRR_ACCESSION)_1.fastq" && \
	test -s "$(FASTQ_DIR)/$(SRR_ACCESSION)_2.fastq" || { \
		echo "ERROR: Missing paired FASTQs" >&2; exit 1; \
	}

	gzip -f \
		"$(FASTQ_DIR)/$(SRR_ACCESSION)_1.fastq" \
		"$(FASTQ_DIR)/$(SRR_ACCESSION)_2.fastq"

	mv "$(FASTQ_DIR)/$(SRR_ACCESSION)_1.fastq.gz" "$(FASTQ_R1)"
	mv "$(FASTQ_DIR)/$(SRR_ACCESSION)_2.fastq.gz" "$(FASTQ_R2)"

	rm -rf "$(FASTQ_DIR)/$(SRR_ACCESSION)"

# Ensure the second mate was created by the first recipe.
$(FASTQ_R2): $(FASTQ_R1)
	@test -s "$@" || { \
		echo "ERROR: R2 missing; remove R1 to regenerate both mates" >&2; \
		exit 1; \
	}


# ==========================================================
# 11. SUBSAMPLE PAIRED-END READS
# ==========================================================
# seqtk randomly samples MAX_READ_PAIRS from each FASTQ.
#
# Using the same random seed preserves pairing when R1 and R2
# contain matching reads in the same order.
#
# Original FASTQ files remain unchanged.
# Each read limit has its own output directory.

subset: $(ALIGN_R1) $(ALIGN_R2)

ifneq ($(MAX_READ_PAIRS),all)

$(SUBSET_STAMP): $(FASTQ_R1) $(FASTQ_R2) | check-tools
	@mkdir -p "$(SAMPLE_SUBSET_DIR)"
	@echo ">> Sampling $(MAX_READ_PAIRS) pairs for $(SAMPLE_NAME)"
	@set -e; \
	seqtk sample -s"$(SUBSAMPLE_SEED)" "$(FASTQ_R1)" "$(MAX_READ_PAIRS)" \
	  | gzip > "$(SUBSET_R1).tmp"; \
	seqtk sample -s"$(SUBSAMPLE_SEED)" "$(FASTQ_R2)" "$(MAX_READ_PAIRS)" \
	  | gzip > "$(SUBSET_R2).tmp"; \
	mv "$(SUBSET_R1).tmp" "$(SUBSET_R1)"; \
	mv "$(SUBSET_R2).tmp" "$(SUBSET_R2)"; \
	touch "$@"

$(SUBSET_R1) $(SUBSET_R2): $(SUBSET_STAMP)
	@test -s "$@" || { \
		echo "ERROR: Missing subset file $@" >&2; exit 1; \
	}

endif


# ==========================================================
# 12. ALIGN READS USING BWA-MEM
# ==========================================================
# Only the subsampled reads are used unless
# MAX_READ_PAIRS=all.
#
# BWA aligns against the chosen chromosome reference.
# samtools sort produces a coordinate-sorted BAM file.

align: $(BAM_OUT) $(BAM_OUT).bai

$(RAW_BAM): $(CHR_GENOME).bwt $(ALIGN_R1) $(ALIGN_R2)
	@mkdir -p "$(RUN_ALIGN_DIR)"

	bwa mem \
		-t "$(THREADS)" \
		-R '@RG\tID:$(SAMPLE_NAME)\tSM:$(SAMPLE_NAME)' \
		"$(CHR_GENOME)" \
		"$(ALIGN_R1)" \
		"$(ALIGN_R2)" \
		| samtools sort -@ "$(THREADS)" -o "$@" -


# ==========================================================
# 13. FILTER AND INDEX THE BAM
# ==========================================================
# -f 2: Properly paired reads.
# -F 1804: Exclude unmapped, secondary, QC-failed,
#          duplicate-flagged, and supplementary reads.
# -q 30: Minimum mapping quality.
#
# This workflow does not mark PCR duplicates itself.

$(BAM_OUT): $(RAW_BAM)
	samtools view \
		-@ "$(THREADS)" \
		-b -f 2 -F 1804 -q 30 \
		-o "$@" "$<"

$(BAM_OUT).bai: $(BAM_OUT)
	samtools index "$<"


# ==========================================================
# 14. MACS3 PEAK CALLING
# ==========================================================
# MACS3 identifies regions enriched for ATAC-seq fragments.
#
# -f BAMPE: Use paired-end fragment intervals.
# -g: Effective genome size.
# -q: FDR threshold.
#
# For chromosome-only analysis, the genome-size estimate
# is approximate and should be disclosed in reports.

peaks: $(PEAK_OUT)

$(PEAK_OUT): $(BAM_OUT) $(BAM_OUT).bai $(CHR_GENOME).fai
	@mkdir -p "$(RUN_PEAK_DIR)"

	@gs="$(MACS_GSIZE)"; \
	if [ "$$gs" = auto ]; then \
		gs="$$(awk 'NR==1 {printf "%.0f", $$2*0.8}' "$(CHR_GENOME).fai")"; \
	fi; \
	echo ">> Calling peaks for $(SAMPLE_NAME), genome size $$gs"; \
	macs3 callpeak \
		-t "$(BAM_OUT)" \
		-f BAMPE \
		-g "$$gs" \
		-n "$(SAMPLE_NAME)" \
		--outdir "$(RUN_PEAK_DIR)" \
		-q "$(MACS_QVALUE)" \
		-B

	@test -f "$@"


# ==========================================================
# 15. COUNT PEAKS
# ==========================================================
# Reports peak counts per sample and selected chromosome.

peak-stats: $(PEAK_STATS)

$(PEAK_STATS): $(PEAK_OUT)
	@mkdir -p "$(RUN_REPORT_DIR)"

	@printf 'Sample\tChromosome\tMax_read_pairs\tPeaks\n%s\t%s\t%s\t%s\n' \
		"$(SAMPLE_NAME)" \
		"$(CHROMOSOME)" \
		"$(MAX_READ_PAIRS)" \
		"$$(wc -l < "$(PEAK_OUT)" | tr -d ' ')" > "$@"

	@cat "$@"


# ==========================================================
# 16. GENERATE IGV COVERAGE TRACKS
# ==========================================================
# Generate CPM-normalized bigWig files with deepTools.
# Load .bw and .narrowPeak files into IGV.

tracks: $(BIGWIG_OUT)

$(BIGWIG_OUT): $(BAM_OUT) $(BAM_OUT).bai
	@mkdir -p "$(RUN_TRACK_DIR)"

	bamCoverage \
		-b "$(BAM_OUT)" \
		-o "$@" \
		--binSize 10 \
		--normalizeUsing CPM \
		-p "$(THREADS)"


# ==========================================================
# 17. CLEAN GENERATED FILES
# ==========================================================
# Keep design.csv, environment.yml, and scripts.

clean:
	rm -rf \
		"$(GENOME_DIR)" \
		"$(FASTQ_DIR)" \
		"$(ALIGN_DIR)" \
		"$(PEAK_DIR)" \
		"$(TRACK_DIR)" \
		"$(REPORT_DIR)" \
		design

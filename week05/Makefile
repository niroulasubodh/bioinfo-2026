# Use Bash to run the Makefile commands
SHELL := /bin/bash

# =========================================================
# Generate a BAM File
# Purpose: Downloads Genome of choice, downloads sequencing
# reads from SRA of choice, and aligns reads to create a BAM file.
#
#   make genome   -> download reference genome
#   make fastq    -> download SRA reads (paired-end) sized to target coverage
#   make align    -- align reads and create BAM file
#   make all      -> genome + fastq + align
#   make clean    -> remove all generated files
# =========================================================

# ---------------------------------------------------------
# Choose which genome to use for the analysis
# Put the desired genome accession number and name here so
# that it generates the genome URL
# ---------------------------------------------------------
Genome_Accession_Number ?= GCF_000850405.1
Genome_Accession_Name   ?= ViralMultiSegProj14746
ORG_NAME                ?= orthohantavirus

# "000850405.1" -> "000850405" (drop the version suffix)
DigitsWithVersion := $(word 2,$(subst _, ,$(Genome_Accession_Number)))
Digits            := $(firstword $(subst ., ,$(DigitsWithVersion)))

# "000850405" -> "000/850/405"
TripletPath := $(shell echo $(Digits) | sed -E 's/(.{3})(.{3})(.{3})/\1\/\2\/\3/')

# NCBI's real layout is:
#   genomes/all/GCF/000/850/405/GCF_000850405.1_ViralMultiSegProj14746/GCF_000850405.1_ViralMultiSegProj14746_genomic.fna.gz
# i.e. the triplet path is followed by an assembly-named subdirectory,
# and the file itself ends in "_genomic.fna.gz" (NOT "_genome.fna.gz").
# NOTE: TripletPath has no trailing slash (e.g. "000/850/405"), so an
# explicit "/" is required before AssemblyDir below.
AssemblyDir := $(Genome_Accession_Number)_$(Genome_Accession_Name)
Base_Name   := $(TripletPath)/$(AssemblyDir)/$(AssemblyDir)_genomic.fna.gz
Genome_URL  := https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/$(Base_Name)

# ---------------------------------------------------------
# Choose the SRR accession, and provide the coverage size of
# the genome to estimate the number of reads to download
# ---------------------------------------------------------
SRR_ACCESSION ?= SRR34582745
COVERAGE      ?= 10
# READ_LEN: average read length (bp) of your Illumina paired-end
# reads. Derive it from FastQC as Total Bases / Total Sequences
# (e.g. 1.9 Mbp / 10000 reads = 190). Used only to estimate how
# many read pairs are needed to hit the target COVERAGE -- an
# inaccurate value will over/under-shoot the actual coverage
# achieved, though the pipeline will still run fine.
READ_LEN      ?= 50
# NUM_READS is a fallback/manual override; the fastq target
# will auto-estimate the read count from COVERAGE and genome
# size unless you explicitly pass NUM_READS=<value> on the CLI.
NUM_READS     ?=

# ---------------------------------------------------------
# Folder layout
# ---------------------------------------------------------
GENOME_DIR := genome
FASTQ_DIR  := fastq
ALIGN_DIR  := align

GENOME_GZ    := $(GENOME_DIR)/$(ORG_NAME)_genome.fna.gz
GENOME_FA    := $(GENOME_DIR)/$(ORG_NAME)_genome.fna
GENOME_SIZE_FILE := $(GENOME_DIR)/.genome_size

FASTQ_R1 := $(FASTQ_DIR)/$(ORG_NAME)_1.fastq.gz
FASTQ_R2 := $(FASTQ_DIR)/$(ORG_NAME)_2.fastq.gz
NUM_READS_FILE := $(FASTQ_DIR)/.num_reads

# Signature of the values that affect read-count estimation.
# If any of these change between runs, the cached .num_reads
# file (and therefore the FASTQ files) will be invalidated.
CONFIG_SIG        := $(COVERAGE)-$(READ_LEN)-$(NUM_READS)
CONFIG_SIG_FILE   := $(FASTQ_DIR)/.config_sig

BAM_OUT := $(ALIGN_DIR)/$(ORG_NAME).bam

.PHONY: all genome fastq align clean check-config

all: genome fastq align

# ==========================================================
# GENOME: download genome, decompress a copy for indexing,
# rename using ORG_NAME, and record genome size (bp)
# ==========================================================
genome: $(GENOME_GZ) $(GENOME_FA) $(GENOME_SIZE_FILE)

$(GENOME_GZ):
	@mkdir -p $(GENOME_DIR)
	@echo ">> Downloading genome $(Genome_Accession_Number) ($(ORG_NAME)) ..."
	@echo ">>   URL: $(Genome_URL)"
	curl -fL -o $@ "$(Genome_URL)"

$(GENOME_FA): $(GENOME_GZ)
	@echo ">> Decompressing genome for indexing ..."
	gunzip -k -c $< > $@

$(GENOME_SIZE_FILE): $(GENOME_FA)
	@echo ">> Calculating genome size ..."
	@awk '!/^>/{n+=length($$0)} END{print n}' $< > $@
	@echo ">> Genome size: $$(cat $@) bp"

# ==========================================================
# CHECK-CONFIG: detect changes to COVERAGE / READ_LEN / NUM_READS
# even though they are plain variables, not files. If the
# signature differs from the last cached run, invalidate the
# cached read-count so it gets recomputed (which in turn
# invalidates the FASTQ files via normal timestamp tracking).
# ==========================================================
check-config:
	@mkdir -p $(FASTQ_DIR)
	@PREV=""; \
	if [ -f $(CONFIG_SIG_FILE) ]; then PREV=$$(cat $(CONFIG_SIG_FILE)); fi; \
	if [ "$(CONFIG_SIG)" != "$$PREV" ]; then \
		echo ">> Coverage/read-length/NUM_READS config changed ($$PREV -> $(CONFIG_SIG)); re-estimating read count ..."; \
		rm -f $(NUM_READS_FILE); \
		echo "$(CONFIG_SIG)" > $(CONFIG_SIG_FILE); \
	fi

# ==========================================================
# FASTQ: estimate number of read pairs needed for target
# COVERAGE (based on genome size), then download + rename
# ==========================================================
fastq: check-config $(FASTQ_R1) $(FASTQ_R2)

$(NUM_READS_FILE): $(GENOME_SIZE_FILE)
	@mkdir -p $(FASTQ_DIR)
ifeq ($(strip $(NUM_READS)),)
	@GSIZE=$$(cat $(GENOME_SIZE_FILE)); \
	READS=$$(( (GSIZE * $(COVERAGE)) / (2 * $(READ_LEN)) )); \
	echo "$$READS" > $@; \
	echo ">> Estimated read pairs for $(COVERAGE)x coverage (genome=$${GSIZE}bp, read_len=$(READ_LEN)): $$READS"
else
	@echo "$(NUM_READS)" > $@
	@echo ">> Using manually specified NUM_READS=$(NUM_READS)"
endif

# NOTE: fasterq-dump (unlike the older fastq-dump) has NO -X /
# spot-count-limiting option -- it always extracts the full run.
# So we download the full paired FASTQ files first, then truncate
# each to the estimated number of read pairs using `head` (4 lines
# per FASTQ record) before compressing/renaming.
$(FASTQ_R1) $(FASTQ_R2): $(NUM_READS_FILE)
	@mkdir -p $(FASTQ_DIR)
	@READS=$$(cat $(NUM_READS_FILE)); \
	echo ">> Downloading full run $(SRR_ACCESSION) (will subset to $$READS read pairs after download) ..."; \
	prefetch $(SRR_ACCESSION) -O $(FASTQ_DIR); \
	fasterq-dump --split-files -O $(FASTQ_DIR) $(FASTQ_DIR)/$(SRR_ACCESSION)/$(SRR_ACCESSION).sra
	@echo ">> Subsetting to estimated read count (fasterq-dump has no -X option; truncating post-download) ..."
	@READS=$$(cat $(NUM_READS_FILE)); \
	LINES=$$((READS * 4)); \
	head -n $$LINES $(FASTQ_DIR)/$(SRR_ACCESSION)_1.fastq > $(FASTQ_DIR)/$(SRR_ACCESSION)_1.sub.fastq; \
	head -n $$LINES $(FASTQ_DIR)/$(SRR_ACCESSION)_2.fastq > $(FASTQ_DIR)/$(SRR_ACCESSION)_2.sub.fastq; \
	mv $(FASTQ_DIR)/$(SRR_ACCESSION)_1.sub.fastq $(FASTQ_DIR)/$(SRR_ACCESSION)_1.fastq; \
	mv $(FASTQ_DIR)/$(SRR_ACCESSION)_2.sub.fastq $(FASTQ_DIR)/$(SRR_ACCESSION)_2.fastq
	@echo ">> Compressing and renaming FASTQ files ..."
	gzip -f $(FASTQ_DIR)/$(SRR_ACCESSION)_1.fastq
	gzip -f $(FASTQ_DIR)/$(SRR_ACCESSION)_2.fastq
	mv $(FASTQ_DIR)/$(SRR_ACCESSION)_1.fastq.gz $(FASTQ_R1)
	mv $(FASTQ_DIR)/$(SRR_ACCESSION)_2.fastq.gz $(FASTQ_R2)
	rm -rf $(FASTQ_DIR)/$(SRR_ACCESSION)

# ==========================================================
# ALIGN: index genome, align reads with bwa, sort + index BAM
# ==========================================================
align: $(BAM_OUT)

$(GENOME_FA).bwt: $(GENOME_FA)
	@echo ">> Indexing genome with BWA ..."
	bwa index $(GENOME_FA)

$(BAM_OUT): $(GENOME_FA).bwt $(FASTQ_R1) $(FASTQ_R2)
	@mkdir -p $(ALIGN_DIR)
	@echo ">> Aligning reads to genome and building sorted BAM ..."
	bwa mem -R "@RG\tID:$(ORG_NAME)\tSM:$(ORG_NAME)" $(GENOME_FA) $(FASTQ_R1) $(FASTQ_R2) \
		| samtools sort -o $@ -
	samtools index $@
	@echo ">> BAM file created: $@"

# ==========================================================
# CLEAN
# ==========================================================
clean:
	rm -rf $(GENOME_DIR) $(FASTQ_DIR) $(ALIGN_DIR)
	@echo ">> Cleaned up all generated files and directories."
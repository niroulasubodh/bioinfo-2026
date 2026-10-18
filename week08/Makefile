# Use Bash to run the Makefile commands
SHELL := /bin/bash
.DEFAULT_GOAL := all

# Use the project environment when installed; an active environment also works.
TOOLS_DIR ?= $(CURDIR)/.bioinfo-env/bin
export PATH := $(TOOLS_DIR):$(PATH)
# Stop on command failures, including failures within pipes.
.SHELLFLAGS := -eu -o pipefail -c

# Remove incomplete targets if their recipes fail.
.DELETE_ON_ERROR:

# Keep the existing download/configuration recipes sequential.
.NOTPARALLEL:

# =========================================================
# Generate a multi-sample VCF + annotate variant effects
# Purpose: Downloads a reference genome + GFF annotation once,
# then for each sample: downloads SRA reads, aligns, calls
# variants. Finally merges all per-sample VCFs and annotates
# coding effects with bcftools csq.
#
#   make genome      -> download reference genome
#   make annotation  -> download reference GFF (gene models)
#   make fastq       -> download SRA reads (paired-end) sized to target coverage
#   make align       -> align reads and create BAM file
#   make variants     -> call variants for ONE sample (SRR_ACCESSION + SAMPLE_NAME)
#   make all          -> genome + fastq + align + coverage + variants + stats (one sample)
#   make merge        -> merge per-sample VCFs listed in SAMPLES into one multi-sample VCF
#   make annotate     -> annotate the merged VCF with bcftools csq (gene/codon/AA change)
#   make coding       -> list only the variants that fall in coding regions (have a BCSQ tag)
#   make clean        -> remove all generated files
#
# Typical workflow for the assignment (>= 3 samples):
#   make all SRR_ACCESSION=SRR1111111 SAMPLE_NAME=SampleA
#   make all SRR_ACCESSION=SRR2222222 SAMPLE_NAME=SampleB
#   make all SRR_ACCESSION=SRR3333333 SAMPLE_NAME=SampleC
#   make merge annotate SAMPLES="SampleA SampleB SampleC"
#   make coding SAMPLES="SampleA SampleB SampleC"
# =========================================================

# ---------------------------------------------------------
# Choose which genome to use for the analysis
# Put the desired genome accession number and name here so
# that it generates the genome URL
# ---------------------------------------------------------
Genome_Accession_Number ?= GCA_037915055.1
Genome_Accession_Name   ?= ASM3791505v1
ORG_NAME                ?= InfluenzaA

# NCBI keeps GenBank (GCA_...) and RefSeq (GCF_...) assemblies in
# SEPARATE top-level FTP folders (genomes/all/GCA/... vs genomes/all/GCF/...).
# The prefix must match whichever accession you actually provide -- e.g. a
# GCA_ accession under the GCF/ folder path 404s even though the triplet
# path and filename otherwise look correct.
# "GCA_037915055.1" -> "GCA"   /   "GCF_000850405.1" -> "GCF"
AssemblyPrefix := $(word 1,$(subst _, ,$(Genome_Accession_Number)))

# "000850405.1" -> "000850405" (drop the version suffix)
DigitsWithVersion := $(word 2,$(subst _, ,$(Genome_Accession_Number)))
Digits            := $(firstword $(subst ., ,$(DigitsWithVersion)))

# "000850405" -> "000/850/405"
TripletPath := $(shell echo $(Digits) | sed -E 's/(.{3})(.{3})(.{3})/\1\/\2\/\3/')

# NCBI's real layout is:
#   genomes/all/GCF/000/850/405/GCF_000850405.1_ViralMultiSegProj14746/GCF_000850405.1_ViralMultiSegProj14746_genomic.fna.gz
#   (or genomes/all/GCA/... when Genome_Accession_Number starts with GCA_)
# i.e. the triplet path is followed by an assembly-named subdirectory,
# and the file itself ends in "_genomic.fna.gz" (NOT "_genome.fna.gz").
# The matching gene-model annotation lives alongside it as
# "_genomic.gff.gz". NOTE: TripletPath has no trailing slash (e.g.
# "000/850/405"), so an explicit "/" is required before AssemblyDir below.
AssemblyDir   := $(Genome_Accession_Number)_$(Genome_Accession_Name)
Base_Name     := $(TripletPath)/$(AssemblyDir)/$(AssemblyDir)_genomic.fna.gz
GFF_Base_Name := $(TripletPath)/$(AssemblyDir)/$(AssemblyDir)_genomic.gff.gz
Genome_URL    := https://ftp.ncbi.nlm.nih.gov/genomes/all/$(AssemblyPrefix)/$(Base_Name)
GFF_URL       := https://ftp.ncbi.nlm.nih.gov/genomes/all/$(AssemblyPrefix)/$(GFF_Base_Name)

# ---------------------------------------------------------
# Choose the SRR accession + sample name, and provide the
# coverage size of the genome to estimate the number of reads
# to download. SAMPLE_NAME identifies the BIOLOGICAL SAMPLE
# (its own BAM/VCF/read-group) and defaults to the SRR if not
# given. ORG_NAME/genome files are shared across all samples.
# ---------------------------------------------------------
SRR_ACCESSION ?= SRR31107661	
SAMPLE_NAME   ?= $(SRR_ACCESSION)
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

# List of sample names to combine for merge/annotate/coding.
# Pass on the command line, e.g.:
#   make merge annotate SAMPLES="SampleA SampleB SampleC"
SAMPLES ?= $(SAMPLE_NAME)

# ---------------------------------------------------------
# Folder layout
# ---------------------------------------------------------
GENOME_DIR  := genome
FASTQ_DIR   := fastq
ALIGN_DIR   := align
VARIANT_DIR := variants
REPORT_DIR  := reports

GENOME_GZ         := $(GENOME_DIR)/$(ORG_NAME)_genome.fna.gz
GENOME_FA         := $(GENOME_DIR)/$(ORG_NAME)_genome.fna
GENOME_SIZE_FILE  := $(GENOME_DIR)/.genome_size

GFF_GZ := $(GENOME_DIR)/$(ORG_NAME)_genomic.gff.gz
GFF    := $(GENOME_DIR)/$(ORG_NAME)_genomic.gff

# FASTQ/BAM/per-sample VCF files are keyed on SAMPLE_NAME so that
# multiple samples coexist side by side instead of overwriting
# each other (the genome, keyed on ORG_NAME, is shared).
FASTQ_R1       := $(FASTQ_DIR)/$(SAMPLE_NAME)_1.fastq.gz
FASTQ_R2       := $(FASTQ_DIR)/$(SAMPLE_NAME)_2.fastq.gz
NUM_READS_FILE := $(FASTQ_DIR)/$(SAMPLE_NAME).num_reads

# Signature of the values that affect read-count estimation.
# If any of these change between runs, the cached .num_reads
# file (and therefore the FASTQ files) will be invalidated.
CONFIG_SIG      := $(SRR_ACCESSION)-$(Genome_Accession_Number)-$(COVERAGE)-$(READ_LEN)-$(NUM_READS)
CONFIG_SIG_FILE := $(FASTQ_DIR)/$(SAMPLE_NAME).config_sig

BAM_OUT := $(ALIGN_DIR)/$(SAMPLE_NAME).bam

VCF_OUT   := $(VARIANT_DIR)/$(SAMPLE_NAME).vcf.gz
VCF_STATS := $(REPORT_DIR)/$(SAMPLE_NAME)_vcf_stats.txt

DEPTH_FILE      := $(REPORT_DIR)/$(SAMPLE_NAME)_depth.tsv
COVERAGE_REPORT := $(REPORT_DIR)/$(SAMPLE_NAME)_coverage.txt

# Multi-sample outputs (built from $(SAMPLES), not just SAMPLE_NAME)
MERGED_VCF    := $(VARIANT_DIR)/merged.vcf.gz
ANNOTATED_VCF := $(VARIANT_DIR)/merged.annotated.vcf.gz
CODING_REPORT := $(REPORT_DIR)/coding_variants.txt

# Required mean aligned depth
MIN_MEAN_DEPTH ?= 10

# Haploid calling for the viral reference used here.
# Change this for organisms requiring a different ploidy model.
PLOIDY ?= 1

.PHONY: all genome annotation fastq align clean check-config coverage \
        check-coverage variants stats check-tools merge annotate coding

# Fail early with actionable instructions rather than command-not-found (127).
check-tools:
	@missing=""; for tool in curl gzip prefetch fasterq-dump bwa samtools bcftools; do \
		command -v "$$tool" >/dev/null 2>&1 || missing="$$missing $$tool"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "Missing tools:$$missing" >&2; \
		echo "Install once: conda env create --prefix ./.bioinfo-env --file environment.yml" >&2; \
		echo "Then run: make all (or set TOOLS_DIR=/path/to/environment/bin)" >&2; \
		exit 1; \
	fi

# Order-only checks do not force existing output files to be rebuilt.
$(GENOME_GZ) $(GENOME_FA) $(GENOME_SIZE_FILE) $(GFF_GZ) $(GFF) \
$(NUM_READS_FILE) $(FASTQ_R1) $(FASTQ_R2) $(BAM_OUT): | check-tools

all: genome fastq align variants stats

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
# ANNOTATION: download the matching GFF gene-model annotation
# (same assembly directory as the genome, "_genomic.gff.gz"),
# then patch it into a form bcftools csq can use.
#
# Many NCBI viral GFF3 files (e.g. Influenza A) go straight
# from "gene" to "CDS" with no intermediate "mRNA"/"transcript"
# feature. bcftools csq requires that 3-tier gene -> mRNA -> CDS
# hierarchy to build a transcript model; without it you get:
#   "Error: No usable transcripts found ..."
# $(GFF) is therefore the PATCHED file (what csq/annotate use);
# $(GFF_RAW) is the untouched download, kept only as input.
# ==========================================================
GFF_RAW := $(GENOME_DIR)/$(ORG_NAME)_genomic.raw.gff

annotation: $(GFF)

$(GFF_GZ):
	@mkdir -p $(GENOME_DIR)
	@echo ">> Downloading annotation (GFF) for $(Genome_Accession_Number) ..."
	@echo ">>   URL: $(GFF_URL)"
	curl -fL -o $@ "$(GFF_URL)"

$(GFF_RAW): $(GFF_GZ)
	@echo ">> Decompressing annotation ..."
	gunzip -k -c $< > $@

# Insert a synthetic mRNA feature between each gene and its CDS
# (ID=mrna_<cds-id>; Parent chain: CDS -> mRNA -> gene) so that
# bcftools csq finds a complete transcript model. Safe for simple,
# unspliced gene/CDS pairs (true for the un-spliced influenza
# segments and most small viral genomes); re-check with
# `cut -f3 $(GFF) | sort | uniq -c` if your organism's CDS
# features are more complex (e.g. multi-exon/spliced).
$(GFF): $(GFF_RAW)
	@echo ">> Patching GFF: inserting missing mRNA tier for bcftools csq ..."
	@awk 'BEGIN{FS=OFS="\t"} \
		/^#/{print; next} \
		{ \
			split($$9,a,";"); id=""; parent=""; \
			for(i in a){ if(a[i]~/^ID=/) id=substr(a[i],4); if(a[i]~/^Parent=/) parent=substr(a[i],8) } \
			if($$3=="CDS"){ \
				mrna_id="mrna_"id; \
				print $$1,$$2,"mRNA",$$4,$$5,$$6,$$7,".","ID="mrna_id";Parent="parent; \
				$$9="ID="id";Parent="mrna_id; \
				print $$1,$$2,$$3,$$4,$$5,$$6,$$7,$$8,$$9; \
				next \
			} \
			print \
		}' $< > $@
	@echo ">> Patched GFF created: $@"

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

$(NUM_READS_FILE): $(GENOME_SIZE_FILE) | check-config
	@mkdir -p $(FASTQ_DIR)
ifeq ($(strip $(NUM_READS)),)
	@GSIZE=$$(cat $(GENOME_SIZE_FILE)); \
	READS=$$(( (GSIZE * $(COVERAGE) + 2 * $(READ_LEN) - 1) / (2 * $(READ_LEN)) )); \
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
# Each sample's BAM is tagged with its own @RG SM/ID so that
# joint calling / downstream tools can distinguish samples.
# ==========================================================
align: $(BAM_OUT)

$(GENOME_FA).bwt: $(GENOME_FA) | check-tools
	@echo ">> Indexing genome with BWA ..."
	bwa index $(GENOME_FA)

$(BAM_OUT): $(GENOME_FA).bwt $(FASTQ_R1) $(FASTQ_R2)
	@mkdir -p $(ALIGN_DIR)
	@echo ">> Aligning reads to genome and building sorted BAM for sample $(SAMPLE_NAME) ..."
	bwa mem -R "@RG\tID:$(SAMPLE_NAME)\tSM:$(SAMPLE_NAME)" $(GENOME_FA) $(FASTQ_R1) $(FASTQ_R2) \
		| samtools sort -o $@ -
	samtools index $@
	@echo ">> BAM file created: $@"

# ==========================================================
# INDEXES: reference FASTA and aligned BAM
# ==========================================================

$(GENOME_FA).fai: $(GENOME_FA) | check-tools
	samtools faidx $<

# Separate target so a missing BAM index can be recreated.
$(BAM_OUT).bai: $(BAM_OUT) | check-tools
	samtools index $<

# ==========================================================
# COVERAGE: measure actual aligned depth across the reference
# ==========================================================

coverage: $(COVERAGE_REPORT)
	@cat $(COVERAGE_REPORT)

$(DEPTH_FILE): $(BAM_OUT) | check-tools
	@mkdir -p $(REPORT_DIR)
	samtools depth -aa $(BAM_OUT) > $@

$(COVERAGE_REPORT): $(DEPTH_FILE)
	@awk 'BEGIN { OFS="\t" } \
		{ total += $$3; bases++; if ($$3 >= 10) covered10++ } \
		END { \
			if (bases == 0) { \
				print "ERROR: No reference positions found." > "/dev/stderr"; \
				exit 1; \
			} \
			print "Reference_bases", bases; \
			printf "Mean_depth\t%.6f\n", total / bases; \
			printf "Percent_bases_at_least_10x\t%.2f\n", \
				100 * covered10 / bases; \
		}' $< > $@

# Recheck the threshold whenever variant calling is requested.
# Calculate from raw depths to avoid rounding at the threshold.
check-coverage: $(COVERAGE_REPORT)
	@cat $(COVERAGE_REPORT)
	@awk -v minimum="$(MIN_MEAN_DEPTH)" \
		'{ total += $$3; bases++ } \
		END { \
			if (bases == 0) exit 1; \
			mean = total / bases; \
			if (mean < minimum) { \
				printf "ERROR: Mean depth %.2fx is below %.2fx.\n", \
					mean, minimum > "/dev/stderr"; \
				print "Increase COVERAGE and regenerate the reads and BAM." \
					> "/dev/stderr"; \
				exit 1; \
			} \
			printf "Coverage check passed: %.2fx mean depth.\n", mean; \
		}' $(DEPTH_FILE)

# ==========================================================
# VARIANTS: call variants for ONE sample and create an
# indexed per-sample VCF (variants/<SAMPLE_NAME>.vcf.gz)
# ==========================================================

variants: $(VCF_OUT) $(VCF_OUT).csi

$(VCF_OUT): $(BAM_OUT) $(BAM_OUT).bai $(GENOME_FA) $(GENOME_FA).fai | check-tools check-coverage
	@mkdir -p $(VARIANT_DIR)
	@echo ">> Calling variants for sample $(SAMPLE_NAME) ..."
	bcftools mpileup \
		-Ou \
		-f $(GENOME_FA) \
		-a FORMAT/DP,FORMAT/AD \
		$(BAM_OUT) \
		| bcftools call \
			-mv \
			--ploidy $(PLOIDY) \
			-Oz \
			-o $@
	@echo ">> VCF created: $@"

$(VCF_OUT).csi: $(VCF_OUT) | check-tools
	bcftools index -f $<

# ==========================================================
# STATS: create a VCF statistics report (per sample)
# ==========================================================

stats: $(VCF_STATS)
	@echo ">> Variant summary:"
	@awk '$$1 == "SN"' $(VCF_STATS)

$(VCF_STATS): $(VCF_OUT) $(VCF_OUT).csi | check-tools
	@mkdir -p $(REPORT_DIR)
	bcftools stats $(VCF_OUT) > $@
	@echo ">> Statistics report created: $@"

# ==========================================================
# MERGE: combine per-sample VCFs (variants/<name>.vcf.gz for
# each name in $(SAMPLES)) into one multi-sample VCF. Each
# sample's VCF + index must already exist -- run
# `make all SRR_ACCESSION=... SAMPLE_NAME=...` for every
# sample first.
# ==========================================================

SAMPLE_VCFS := $(foreach s,$(SAMPLES),$(VARIANT_DIR)/$(s).vcf.gz)

merge: $(MERGED_VCF)

$(MERGED_VCF): | check-tools
	@echo ">> Merging VCFs for samples: $(SAMPLES)"
	@for f in $(SAMPLE_VCFS); do \
		if [ ! -f "$$f" ]; then \
			echo "ERROR: missing $$f -- run 'make all SRR_ACCESSION=... SAMPLE_NAME=...' for that sample first." >&2; \
			exit 1; \
		fi; \
	done
	@mkdir -p $(VARIANT_DIR)
	bcftools merge --write-index -O z -o $@ $(SAMPLE_VCFS)
	@echo ">> Merged VCF created: $@"

# ==========================================================
# ANNOTATE: predict variant effects on the merged VCF using
# bcftools csq (needs reference FASTA + GFF gene models).
# Adds an INFO/BCSQ tag per variant with gene, transcript,
# consequence (e.g. missense/synonymous/stop_gained), and
# the amino-acid change (e.g. 156L>156P).
# ==========================================================

annotate: $(ANNOTATED_VCF)

$(ANNOTATED_VCF): $(MERGED_VCF) $(GFF) $(GENOME_FA) $(GENOME_FA).fai | check-tools
	@echo ">> Annotating variant effects with bcftools csq ..."
	bcftools csq \
		-f $(GENOME_FA) \
		-g $(GFF) \
		-p a \
		$(MERGED_VCF) \
		-O z -o $@
	bcftools index -f $@
	@echo ">> Annotated VCF created: $@"
	@echo ">> Inspect with: bcftools view $@ | grep -v '^##' | less -S"

# ==========================================================
# CODING: convenience target that extracts only the variants
# that fall in a coding sequence (i.e. carry a BCSQ tag), for
# picking candidates to report in the README.
# ==========================================================

coding: $(ANNOTATED_VCF)
	@mkdir -p $(REPORT_DIR)
	bcftools view -i 'INFO/BCSQ!="."' $(ANNOTATED_VCF) > $(CODING_REPORT)
	@echo ">> Coding variants written to $(CODING_REPORT)"
	@grep -v '^##' $(CODING_REPORT)

# ==========================================================
# CLEAN
# ==========================================================
clean:
	rm -rf $(GENOME_DIR) $(FASTQ_DIR) $(ALIGN_DIR) $(VARIANT_DIR) $(REPORT_DIR)
	@echo ">> Cleaned up all generated files and directories."

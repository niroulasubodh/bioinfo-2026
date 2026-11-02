# Single-sample variant calling; use `make help` for commands.
SHELL := /bin/bash
.DEFAULT_GOAL := help

TOOLS_DIR ?= $(CURDIR)/.bioinfo-env/bin
export PATH := $(TOOLS_DIR):$(PATH)
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:

.NOTPARALLEL:

# Reference assembly.
Genome_Accession_Number ?= GCA_037915055.1
Genome_Accession_Name   ?= ASM3791505v1
ORG_NAME                ?= InfluenzaA

AssemblyPrefix := $(word 1,$(subst _, ,$(Genome_Accession_Number)))

DigitsWithVersion := $(word 2,$(subst _, ,$(Genome_Accession_Number)))
Digits            := $(firstword $(subst ., ,$(DigitsWithVersion)))

TripletPath := $(shell echo $(Digits) | sed -E 's/(.{3})(.{3})(.{3})/\1\/\2\/\3/')

AssemblyDir   := $(Genome_Accession_Number)_$(Genome_Accession_Name)
Base_Name     := $(TripletPath)/$(AssemblyDir)/$(AssemblyDir)_genomic.fna.gz
GFF_Base_Name := $(TripletPath)/$(AssemblyDir)/$(AssemblyDir)_genomic.gff.gz
Genome_URL    := https://ftp.ncbi.nlm.nih.gov/genomes/all/$(AssemblyPrefix)/$(Base_Name)
GFF_URL       := https://ftp.ncbi.nlm.nih.gov/genomes/all/$(AssemblyPrefix)/$(GFF_Base_Name)

# Sample and read settings. Set NUM_READS= to estimate reads from coverage.
SRR_ACCESSION ?= SRR31107661
SAMPLE_NAME   ?= $(SRR_ACCESSION)
COVERAGE      ?= 10
# Average read length (bp).
READ_LEN      ?= 50
NUM_READS     ?= 10000

# CSV requires Run and Sample (or BioSample); extra columns are metadata.
DESIGN_CSV      ?= design.csv

# Use CSV sample names unless SAMPLES is supplied.
DESIGN_SAMPLES  := $(shell [ -f $(DESIGN_CSV) ] && python3 scripts/split_design.py --samples-only $(DESIGN_CSV) 2>/dev/null)
ifneq ($(strip $(DESIGN_SAMPLES)),)
SAMPLES ?= $(DESIGN_SAMPLES)
else
SAMPLES ?= $(SAMPLE_NAME)
endif

# Batch size and concurrency.
N ?= all
parallel ?= 4
BATCH_COVERAGE ?= 100
BATCH_READ_LEN ?= $(READ_LEN)
BIOPROJECT ?= PRJNA257197
DESIGN_DIR := design
BATCH_ROWS := $(DESIGN_DIR)/.batch_rows.tsv

# Output paths.
GENOME_DIR  := genome
FASTQ_DIR   := fastq
ALIGN_DIR   := align
VARIANT_DIR := variants
REPORT_DIR  := reports
SAMPLE_GROUPS := $(REPORT_DIR)/sample_groups.tsv

GENOME_GZ         := $(GENOME_DIR)/$(ORG_NAME)_genome.fna.gz
GENOME_FA         := $(GENOME_DIR)/$(ORG_NAME)_genome.fna
GENOME_SIZE_FILE  := $(GENOME_DIR)/.genome_size

GFF_GZ := $(GENOME_DIR)/$(ORG_NAME)_genomic.gff.gz
GFF    := $(GENOME_DIR)/$(ORG_NAME)_genomic.gff

FASTQ_R1       := $(FASTQ_DIR)/$(SAMPLE_NAME)_1.fastq.gz
FASTQ_R2       := $(FASTQ_DIR)/$(SAMPLE_NAME)_2.fastq.gz
NUM_READS_FILE := $(FASTQ_DIR)/$(SAMPLE_NAME).num_reads

# Refresh read counts when input settings change.
CONFIG_SIG      := $(SRR_ACCESSION)-$(Genome_Accession_Number)-$(COVERAGE)-$(READ_LEN)-$(NUM_READS)
CONFIG_SIG_FILE := $(FASTQ_DIR)/$(SAMPLE_NAME).config_sig

BAM_OUT := $(ALIGN_DIR)/$(SAMPLE_NAME).bam

VCF_OUT   := $(VARIANT_DIR)/$(SAMPLE_NAME).vcf.gz
VCF_STATS := $(REPORT_DIR)/$(SAMPLE_NAME)_vcf_stats.txt

DEPTH_FILE      := $(REPORT_DIR)/$(SAMPLE_NAME)_depth.tsv
COVERAGE_REPORT := $(REPORT_DIR)/$(SAMPLE_NAME)_coverage.txt

MERGED_VCF    := $(VARIANT_DIR)/merged.vcf.gz
ANNOTATED_VCF := $(VARIANT_DIR)/merged.annotated.vcf.gz
CODING_REPORT := $(REPORT_DIR)/coding_variants.txt

# Minimum aligned depth and calling ploidy.
MIN_MEAN_DEPTH ?= 10

PLOIDY ?= 1

.PHONY: all single-all prepare-shared genome annotation fastq align clean check-config coverage \
        check-coverage variants stats check-tools merge annotate coding help design download-design

help:
	@echo "Single-sample variant calling Makefile"
	@echo "  make single-all SRR_ACCESSION=SRR12345 SAMPLE_NAME=SampleA"
	@echo "  make all SRR_ACCESSION=SRR12345 SAMPLE_NAME=SampleA  # identical"
	@echo "  make prepare-shared  # once, before running parallel samples"
	@echo "  make download-design BIOPROJECT=PRJNA257197 # download SRA metadata"
	@echo "  make design parallel=4 N=10       # first 10 CSV samples; 4 in parallel"
	@echo "  make design parallel=4 N=all      # all CSV samples; 4 in parallel"
	@echo "  make merge annotate coding SAMPLES="..."   # merge selected samples"
	@echo "  make clean                       # delete generated files"

check-tools:
	@missing=""; for tool in curl gzip fastq-dump bwa samtools bcftools; do \
		command -v "$$tool" >/dev/null 2>&1 || missing="$$missing $$tool"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "Missing tools:$$missing" >&2; \
		echo "Install once: conda env create --prefix ./.bioinfo-env --file environment.yml" >&2; \
		echo "Then run: make all (or set TOOLS_DIR=/path/to/environment/bin)" >&2; \
		exit 1; \
	fi

$(GENOME_GZ) $(GENOME_FA) $(GENOME_SIZE_FILE) $(GFF_GZ) $(GFF) \
$(NUM_READS_FILE) $(FASTQ_R1) $(FASTQ_R2) $(BAM_OUT): | check-tools

single-all: genome fastq align variants stats

all: single-all

# Prepare the shared reference before parallel runs.
prepare-shared: genome annotation $(GENOME_FA).bwt $(GENOME_FA).fai

.PHONY: download-design

BIOPROJECT ?= PRJNA1177455
DESIGN_CSV ?= design.csv

download-design:
	@bash scripts/download_design.sh "$(BIOPROJECT)" "$(DESIGN_CSV)"

.PHONY: design

parallel ?= 4
# Batch size and concurrency.
N ?= all

design:
	@bash scripts/run_parallel.sh "$(parallel)" "$(DESIGN_CSV)" "$(N)" "$(BATCH_COVERAGE)" "$(BATCH_READ_LEN)"

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

# Keep the original GFF; add mRNA features for bcftools csq.
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

# Assumes simple, unspliced gene/CDS pairs; review for spliced annotations.
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

check-config:
	@mkdir -p $(FASTQ_DIR)
	@PREV=""; \
	if [ -f $(CONFIG_SIG_FILE) ]; then PREV=$$(cat $(CONFIG_SIG_FILE)); fi; \
	if [ "$(CONFIG_SIG)" != "$$PREV" ]; then \
		echo ">> Coverage/read-length/NUM_READS config changed ($$PREV -> $(CONFIG_SIG)); re-estimating read count ..."; \
		rm -f $(NUM_READS_FILE); \
		echo "$(CONFIG_SIG)" > $(CONFIG_SIG_FILE); \
	fi

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

$(FASTQ_R1) $(FASTQ_R2): $(NUM_READS_FILE)
	@mkdir -p $(FASTQ_DIR)
	@READS=$$(cat $(NUM_READS_FILE)); \
	echo ">> Downloading up to $$READS spots from $(SRR_ACCESSION) ..."; \
	fastq-dump -X "$$READS" --split-files --gzip --outdir $(FASTQ_DIR) $(SRR_ACCESSION)
	@if [ "$(SRR_ACCESSION)" != "$(SAMPLE_NAME)" ]; then \
		mv $(FASTQ_DIR)/$(SRR_ACCESSION)_1.fastq.gz $(FASTQ_R1); \
		mv $(FASTQ_DIR)/$(SRR_ACCESSION)_2.fastq.gz $(FASTQ_R2); \
	fi

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

$(GENOME_FA).fai: $(GENOME_FA) | check-tools
	samtools faidx $<

$(BAM_OUT).bai: $(BAM_OUT) | check-tools
	samtools index $<

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

# Check unrounded mean depth before calling variants.
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

stats: $(VCF_STATS)
	@echo ">> Variant summary:"
	@awk '$$1 == "SN"' $(VCF_STATS)

$(VCF_STATS): $(VCF_OUT) $(VCF_OUT).csi | check-tools
	@mkdir -p $(REPORT_DIR)
	bcftools stats $(VCF_OUT) > $@
	@echo ">> Statistics report created: $@"

SAMPLE_VCFS := $(foreach s,$(SAMPLES),$(VARIANT_DIR)/$(s).vcf.gz)

merge: $(MERGED_VCF)

# Per-sample VCFs and indexes must already exist.
$(MERGED_VCF): | check-tools
	@echo ">> Merging VCFs for samples: $(SAMPLES)"
	@for f in $(SAMPLE_VCFS); do \
		if [ ! -f "$$f" ]; then \
			echo "ERROR: missing $$f -- run 'make all SRR_ACCESSION=... SAMPLE_NAME=...' (or run_parallel.sh) for that sample first." >&2; \
			exit 1; \
		fi; \
	done
	@mkdir -p $(VARIANT_DIR)
	bcftools merge --write-index -O z -o $@ $(SAMPLE_VCFS)
	@echo ">> Merged VCF created: $@"

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

coding: $(ANNOTATED_VCF)
	@mkdir -p $(REPORT_DIR)
	bcftools view -i 'INFO/BCSQ!="."' $(ANNOTATED_VCF) > $(CODING_REPORT)
	@echo ">> Coding variants written to $(CODING_REPORT)"
	@grep -v '^##' $(CODING_REPORT)

clean:
	rm -rf $(GENOME_DIR) $(FASTQ_DIR) $(ALIGN_DIR) $(VARIANT_DIR) $(REPORT_DIR) design
	@echo ">> Cleaned up all generated files and directories (design.csv you authored is kept; delete manually if desired)."

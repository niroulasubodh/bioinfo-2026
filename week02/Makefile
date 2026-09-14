# ==============================================================================
# Makefile: Download and prepare GCF_000850405.1_ViralMultiSegProj14746
#           (Orthohantavirus) genome for visualization in IGV
#
#           Downloaded .gz archives keep NCBI's original accession-based
#           filenames (required for the download URL to resolve). All
#           decompressed/derived output files are renamed to use the
#           organism name "orthohantavirus" instead.
# ==============================================================================
#
# Requirements (install before running):
#   - wget
#   - gunzip / gzip
#   - samtools   (for FASTA indexing: sudo apt install samtools)
#   - tabix/bgzip (part of htslib, usually installed with samtools)
#   - IGV        (optional; needed only for the igv target)
#
# Usage:
#   make help      # show available targets
#   make           # build everything and print an overview
#   make fasta     # only fetch + index the FASTA
#   make gff       # only fetch + sort/index the GFF
#   make stats     # show genome size and annotation count
#   make index     # build both FASTA and GFF indexes
#   make igv       # launch the prepared files in IGV
#   make clean     # remove generated files
#   make distclean # remove the datasets/ directory entirely
#
# ==============================================================================

SHELL := /bin/bash
.DELETE_ON_ERROR:
.SHELLFLAGS := -o pipefail -c

# ---- Configuration ----------------------------------------------------------
ACCESSION   := GCF_000850405.1
ASM_NAME    := ViralMultiSegProj14746
BASE_NAME   := $(ACCESSION)_$(ASM_NAME)

BASE_URL    := https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/850/405/$(BASE_NAME)

# Downloaded archive names must match NCBI exactly - do not change these.
FASTA_GZ    := $(BASE_NAME)_genomic.fna.gz
GFF_GZ      := $(BASE_NAME)_genomic.gff.gz

# Organism name used only for the decompressed/derived output files.
ORG_NAME    := orthohantavirus

DATASETS_DIR := datasets
FASTA_DIR    := $(DATASETS_DIR)/fasta
GFF_DIR      := $(DATASETS_DIR)/gff

FASTA_FILE  := $(FASTA_DIR)/$(ORG_NAME)_genomic.fna
GFF_FILE    := $(GFF_DIR)/$(ORG_NAME)_genomic.gff

FASTA_INDEX     := $(FASTA_FILE).fai
GFF_SORTED_GZ   := $(GFF_DIR)/$(ORG_NAME)_genomic.sorted.gff.gz
GFF_SORTED_TBI  := $(GFF_SORTED_GZ).tbi

WGET_OPTS := -c --no-verbose --show-progress

# ---- Top level ----------------------------------------------------------
.PHONY: all dirs fasta gff stats index igv clean distclean help

all: stats index
	@echo ""
	@echo "Ready for visualization:"
	@echo "  FASTA : $(FASTA_FILE) (+ .fai index)"
	@echo "  GFF   : $(GFF_SORTED_GZ) (+ .tbi index)"

help:
	@echo "Targets: all, dirs, fasta, gff, stats, index, igv, clean, distclean"

# ---- Directory setup ------------------------------------------------------
dirs:
	@mkdir -p $(FASTA_DIR) $(GFF_DIR)

# ---- FASTA: download, decompress, index -----------------------------------
fasta: dirs $(FASTA_INDEX)

$(FASTA_DIR)/$(FASTA_GZ): dirs
	wget $(WGET_OPTS) -O $@ $(BASE_URL)/$(FASTA_GZ)

$(FASTA_FILE): $(FASTA_DIR)/$(FASTA_GZ)
	gunzip -k -f $<
	mv $(FASTA_DIR)/$(BASE_NAME)_genomic.fna $(FASTA_FILE)

$(FASTA_INDEX): $(FASTA_FILE)
	samtools faidx $(FASTA_FILE)

# ---- GFF: download, decompress, sort, bgzip, tabix-index -------------------
gff: dirs $(GFF_SORTED_TBI)

$(GFF_DIR)/$(GFF_GZ): dirs
	wget $(WGET_OPTS) -O $@ $(BASE_URL)/$(GFF_GZ)

$(GFF_FILE): $(GFF_DIR)/$(GFF_GZ)
	gunzip -k -f $<
	mv $(GFF_DIR)/$(BASE_NAME)_genomic.gff $(GFF_FILE)

# Sort GFF: keep header/comment lines (#) at top, sort features by
# chrom then start coordinate — required for tabix indexing.
$(GFF_SORTED_GZ): $(GFF_FILE)
	( grep "^#" $(GFF_FILE); grep -v "^#" $(GFF_FILE) | sort -k1,1 -k4,4n ) \
		| bgzip > $@

$(GFF_SORTED_TBI): $(GFF_SORTED_GZ)
	tabix -p gff $(GFF_SORTED_GZ)

# ---- Useful summary information --------------------------------------------
stats: $(FASTA_FILE) $(GFF_FILE)
	@echo "Genome size: $$(awk '!/^>/ {gsub(/[[:space:]]/, ""); n += length} END {print n+0}' $(FASTA_FILE)) bp"
	@echo "Number of annotations: $$(awk '!/^#/ && NF {n++} END {print n+0}' $(GFF_FILE))"

index: $(FASTA_INDEX) $(GFF_SORTED_TBI)

# ---- Launch in IGV --------------------------------------------------------
igv: index
	@if command -v igv >/dev/null 2>&1; then \
		echo "Launching IGV..."; \
		igv -g $(FASTA_FILE) $(GFF_SORTED_GZ); \
	elif command -v igv.sh >/dev/null 2>&1; then \
		echo "Launching IGV..."; \
		igv.sh -g $(FASTA_FILE) $(GFF_SORTED_GZ); \
	else \
		echo "IGV was not found in PATH."; \
		echo "Install IGV and ensure the 'igv' command is available."; \
		exit 1; \
	fi

# ---- Cleanup ----------------------------------------------------------
clean:
	rm -f $(FASTA_DIR)/*.gz $(GFF_DIR)/*.gz $(GFF_SORTED_GZ) $(GFF_SORTED_TBI) $(FASTA_INDEX) $(FASTA_FILE) $(GFF_FILE)

distclean:
	rm -rf $(DATASETS_DIR)

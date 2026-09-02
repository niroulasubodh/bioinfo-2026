BASE_URL := https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/850/405/GCF_000850405.1_ViralMultiSegProj14746
REMOTE_PREFIX := GCF_000850405.1_ViralMultiSegProj14746
LOCAL_PREFIX := Orthohantavirus_andesense

DATASETS_DIR := datasets
FASTA_DIR := $(DATASETS_DIR)/fasta
GFF_DIR := $(DATASETS_DIR)/gff

SAMTOOLS ?= samtools
BGZIP ?= bgzip
TABIX ?= tabix

FASTA_SUFFIXES := \
	cds_from_genomic.fna.gz \
	genomic.fna.gz \
	protein.faa.gz \
	translated_cds.faa.gz

FASTA_FILES := $(addprefix $(FASTA_DIR)/$(LOCAL_PREFIX)_,$(FASTA_SUFFIXES))
REFERENCE_GZ := $(FASTA_DIR)/$(LOCAL_PREFIX)_genomic.fna.gz
REFERENCE_FASTA := $(FASTA_DIR)/$(LOCAL_PREFIX)_genomic.fna
REFERENCE_INDEX := $(REFERENCE_FASTA).fai

GFF_FILE := $(GFF_DIR)/$(LOCAL_PREFIX)_genomic.gff
GFF_BGZIP := $(GFF_FILE).gz
GFF_INDEX := $(GFF_BGZIP).tbi

.PHONY: all download fasta gff index check-samtools check-bgzip check-tabix

all: index

download: fasta gff

fasta: $(FASTA_FILES)

gff: $(GFF_BGZIP)

index: $(REFERENCE_INDEX) $(GFF_INDEX)

# Download each FASTA using the descriptive local filename.
$(FASTA_DIR)/$(LOCAL_PREFIX)_%:
	mkdir -p "$(@D)"
	curl --fail --location --retry 3 --output "$@.tmp" "$(BASE_URL)/$(REMOTE_PREFIX)_$*"
	mv "$@.tmp" "$@"

# Decompress the genomic nucleotide FASTA.
$(REFERENCE_FASTA): $(REFERENCE_GZ)
	gzip -dc "$<" > "$@.tmp"
	mv "$@.tmp" "$@"

$(REFERENCE_INDEX): $(REFERENCE_FASTA) | check-samtools
	$(SAMTOOLS) faidx "$<"

# Download and unpack the GFF before recompressing it with bgzip for Tabix.
$(GFF_FILE):
	mkdir -p "$(@D)"
	curl --fail --location --retry 3 --output "$@.download.gz" "$(BASE_URL)/$(REMOTE_PREFIX)_genomic.gff.gz"
	gzip -dc "$@.download.gz" > "$@.tmp"
	mv "$@.tmp" "$@"
	rm -f "$@.download.gz"

$(GFF_BGZIP): $(GFF_FILE) | check-bgzip
	$(BGZIP) -c "$<" > "$@.tmp"
	mv "$@.tmp" "$@"

$(GFF_INDEX): $(GFF_BGZIP) | check-tabix
	$(TABIX) --force --preset gff "$<"

check-samtools:
	@command -v "$(SAMTOOLS)" >/dev/null || { echo "Missing samtools. Activate bioinfo or install it with: brew install samtools" >&2; exit 1; }

check-bgzip:
	@command -v "$(BGZIP)" >/dev/null || { echo "Missing bgzip. Activate bioinfo or install it with: brew install htslib" >&2; exit 1; }

check-tabix:
	@command -v "$(TABIX)" >/dev/null || { echo "Missing tabix. Activate bioinfo or install it with: brew install htslib" >&2; exit 1; }
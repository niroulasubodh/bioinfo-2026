# *Orthohantavirus andesense* Genome Visualization

This project visualizes genomic data from *Orthohantavirus andesense* using IGV. IGV (the Integrative Genomics Viewer) is a bioinformatics tool used to visually explore the large genomic datasets. 

### Prerequisites

* [IGV](https://igv.org/download/html/oldtempfixForDownload.html) installed locally.

## About *Orthohantavirus andesense*

* **Accession:** [NC_003467](https://www.ncbi.nlm.nih.gov/nuccore/NC_003467.2_)
* **Genome Size:** 12.1 kb
* **Number of Chromosomes:** 3
* **[Number of Annotiations](https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/850/405/GCF_000850405.1_ViralMultiSegProj14746/GCF_000850405.1_ViralMultiSegProj14746_feature_count.txt):** 8 (4 protein-coding genes and 4 corresponding coding sequences)
* **Genome Architecture:** Negative-sense, single-stranded RNA (ssRNA) organized into three segments:
  * **Small (S):** Encodes the nucleocapsid protein (N).
  * **Medium (M):** Encodes the envelope glycoprotein precursor (GPC), cleaved into Gn and Gc.
  * **Large (L):** Encodes the viral RNA-dependent RNA polymerase (RdRp).
* **Significance:** Andes virus is the primary causative agent of Hantavirus Cardiopulmonary Syndrome (HCPS) in South America and is uniquely notable among hantaviruses for documented person-to-person transmission.

## Visualizations

* Run Makefile
* It generates FASTA and GFF files
* Visualize using IGV

## Observations

## References and Data Sources

1. **Primary Genome Characterization:**
   * Meissner, J. D., Rowe, J. E., Borucki, M. K., & St Jeor, S. C. (2002). Complete nucleotide sequence of a Chilean hantavirus. *Virus Research*, 89(1), 131–143. [https://doi.org/10.1016/S0168-1702(02)00129-6](https://doi.org/10.1016/S0168-1702(02)00129-6)

2. **NCBI Reference Assembly:**
   * National Center for Biotechnology Information. *Orthohantavirus andesense* RefSeq Assembly. Accession: `GCF_000850405.1` (ViralMultiSegProj14746). [https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000850405.1/](https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_000850405.1/)

3. **Genomic Segment Reference Sequences (NCBI Nucleotide):**
   * **Segment M (GPC precursor):** [NCBI RefSeq NC_003467.2](https://www.ncbi.nlm.nih.gov/nuccore/NC_003467.2) (*Andes virus isolate Chile-9717869 segment M, complete sequence*).
   * **Segment S (N protein):** [NCBI RefSeq NC_003466.1](https://www.ncbi.nlm.nih.gov/nuccore/NC_003466.1)
   * **Segment L (RdRp):** [NCBI RefSeq NC_003468.2](https://www.ncbi.nlm.nih.gov/nuccore/NC_003468.2)


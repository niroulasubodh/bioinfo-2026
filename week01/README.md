## Basic Bioinformatics Commands


#### What version is your *samtools* command in the *bioinfo* environment?

```
# Change the directory where your bioinfo environment is set up
cd ~/BMMB_825/bioinfo

#Activate the env to bioinfo
bioinfo

#Check the version of samtools
samtools
```

**Output** <br>
Program: *samtools* (Tools for alignments in the SAM format) <br>
Version: 1.24 (using htslib 1.24)

#### Show commands needed to create a nested directory structure.

```
# Make nested directory
mkdir -p bioinfo_2026/week01/data/scripts

#View them in a tree
tree bioinfo_2026
```
**Output** <br>
bioinfo_2026/<br>
└── week01<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;└── data<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;└── scripts<br>

4 directories, 0 files

#### Show commands that create files in different directories

```
##Create 'sample.csv' file inside the data folder 
touch bioinfo_2026/week01/data/sample.csv

#Create 'analysis.R' file inside the scripts folder 
touch bioinfo_2026/week01/data/scripts/anaysis.R

#View the created files
ls bioinfo_2026/week01/data/
ls bioinfo_2026/week01/data/scripts/
```
**Output** <br>
sample.csv scripts  <br>
analysis.R

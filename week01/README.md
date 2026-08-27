## Basic Bioinformatics Commands

**Editor:** VSCode

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
mkdir -p bioinfo_2026/week01/scripts | mkdir -p bioinfo_2026/week01/data

#View them in a tree
tree bioinfo_2026
```
**Output** <br>
week01/<br>
└── README.md<br>
└── data<br>
└── scripts<br>

3 directories, 1 files

#### Show commands that create files in different directories

```
##Create 'sample.csv' file inside the data folder 
touch week01/data/sample.csv

#Create 'analysis.R' file inside the scripts folder 
touch week01/data/scripts/anaysis.R

#View the created files
ls bioinfo_2026/week01/data/
ls bioinfo_2026/week01/data/scripts/
```
**Output** <br>
week01/<br>
└── README.md<br>
└── data<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;└── sample.csv <br>
└── scripts<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;└── anaysis.R

3 directories, 3 files

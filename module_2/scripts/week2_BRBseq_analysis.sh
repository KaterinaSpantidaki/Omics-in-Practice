# Module 2
# Aikaterini Spantidaki
# 12/11/2026


# Set my directory.
cd /scratch/Omics_in_practice/aspantidaki/

# Run the file which contains all the software paths. 
source /scratch/Omics_in_practice/aspantidaki/.bashrc

# Link the course FASTQ files into my fastq directory. 
cd /scratch/Omics_in_practice/aspantidaki/projects/brbseq/fastq
ln -s /scratch/Omics_in_practice/data/BRBseq/Omics_BRBseq_MQ_UDI_1_R1.fastq.gz Omics_BRBseq_MQ_UDI_1_R1.fastq.gz 
ln -s /scratch/Omics_in_practice/data/BRBseq/Omics_BRBseq_MQ_UDI_1_R2.fastq.gz Omics_BRBseq_MQ_UDI_1_R2.fastq.gz

# List the files, the permissions and the sizes of the files. 
ls -lh 

# Check that gzip files are readable without fully decompressing them.
gzip -t Omics_BRBseq_MQ_UDI_1_R1.fastq.gz
gzip -t Omics_BRBseq_MQ_UDI_1_R2.fastq.gz
echo $?

# View the first record of each file.
zcat Omics_BRBseq_MQ_UDI_1_R1.fastq.gz | head -n 4
zcat Omics_BRBseq_MQ_UDI_1_R2.fastq.gz | head -n 4

# Create a dedicated output directory and run both paired files.
mkdir -p /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/fastqc

fastqc \
	fastq/Omics_BRBseq_MQ_UDI_1_R1.fastq.gz \
	fastq/Omics_BRBseq_MQ_UDI_1_R2.fastq.gz \
	--outdir results/fastqc \
	--threads 4
	
# Check the output which should include an HTML report and ZIP archive for each input file.
ls -lh results/fastqc


# Obtain the path for the star files. 
export GENOME_DIR=/scratch/Omics_in_practice/genomes/GRCh38/index/star/
ls -lh "$GENOME_DIR" | head

# Confirm that the directory is readable.
test -r "$GENOME_DIR/Genome" && echo "Genome index is readable"

# STARsolo uses a whitelist containing the expected barcode sequences. 
# Use the whitelist that matches the MERCURIUS kit and barcode plate version. 
# Do not create a new whitelist by copying only the few example barcodes in a protocol.
mkdir -p /scratch/Omics_in_practice/aspantidaki/projects/brbseq/barcodes
cp /scratch/Omics_in_practice/data/BRBseq/barcodes.txt /scratch/Omics_in_practice/aspantidaki/projects/brbseq/barcodes
wc -l barcodes.txt
head barcodes.txt

# Each line must contain one barcode sequence and no header. 
# For a V5 barcode set, each barcode is typically 14 nucleotides long. 
# Check the observed lengths.
awk '{print length($0)}' barcodes.txt | sort -nu  ### It is indeed 14

# Meanings
	#--soloCBstart 1 Barcode starts at first base of R1

	#--soloCBlen 14 Barcode length

	#--soloUMIstart 15 UMI begins immediately after barcode

	#--soloUMIlen 14 UMI length
	

### Prepare the STARsolo command ###

# Create an output directory. 
# The trailing slash in the output prefix is useful because STAR writes several files and folders with that prefix.
mkdir -p starsolo

STAR \
    --runMode alignReads \
    --outSAMmapqUnique 60 \
    --runThreadN 8 \
    --outSAMunmapped Within \
    --soloStrand Forward \
    --quantMode GeneCounts \
    --outBAMsortingThreadN 8 \
    --genomeDir /scratch/Omics_in_practice/genomes/GRCh38/index/star/ \
    --soloType CB_UMI_Simple \
    --soloCBstart 1 \
    --soloCBlen 14 \
    --soloUMIstart 15 \
    --soloUMIlen 14 \
    --soloUMIdedup NoDedup 1MM_Directional \
    --soloCellFilter None \
    --soloCBwhitelist barcodes/barcodes.txt \
    --soloBarcodeReadLength 0 \
    --soloFeatures Gene \
    --outSAMattributes NH HI nM AS CR UR CB UB GX GN sS sQ sM \
    --outFilterMultimapNmax 1 \
    --readFilesCommand zcat \
    --outSAMtype BAM SortedByCoordinate \
    --outFileNamePrefix results/starsolo/ \
    --readFilesIn fastq/Omics_BRBseq_MQ_UDI_1_R2.fastq.gz fastq/Omics_BRBseq_MQ_UDI_1_R1.fastq.gz
	
# Save the command as a script to improve reproducibility. 

# Make an empty script.
touch /scratch/Omics_in_practice/aspantidaki/projects/brbseq/scripts/run_starsolo.sh

# Paste the above STAR command in it. 
nano run_starsolo.sh

# Make it executable. 
chmod +x /scratch/Omics_in_practice/aspantidaki/projects/brbseq/scripts/run_starsolo.sh

# Run the bash script.
bash scripts/run_starsolo.sh 2>&1 | tee logs/starsolo_console.log

# Inspect the log files.
tail -f /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Log.progress.out
#   Time    Speed        Read     Read   Mapped   Mapped   Mapped   Mapped Unmapped Unmapped Unmapped Unmapped
#            M/hr      number   length   unique   length   MMrate    multi   multi+       MM    short    other
# Nov 12 14:54:13   1378.8    22980207       59    71.9%     58.2     0.5%     0.0%    23.3%     0.0%     4.6%     0.2%
# Nov 12 14:55:44    947.9    39758296       59    71.8%     58.2     0.4%     0.0%    23.2%     0.0%     4.8%     0.2%

# List the main outputs.
find /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo -maxdepth 2 -type f | sort | head -n 30
	# Aligned.sortedByCoord.out.bam --> Coordinate-sorted genome alignments
	# Log.final.out --> Final alignment summary
	# Log.out --> Detailed STAR run log
	# Log.progress.out --> Progress during alignment
	# Solo.out/ --> STARsolo barcode and matrix outputs
	# ReadsPerGene.out.tab --> Gene-count output from --quantMode GeneCounts

# Confirm the BAM file is present and non-empty.
ls -lh /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Aligned.sortedByCoord.out.bam

# Verify the BAM file using Samtools:
samtools quickcheck -v /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Aligned.sortedByCoord.out.bam
samtools view -H /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Aligned.sortedByCoord.out.bam | head

# Inspect barcode statistics.
less /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Solo.out/Barcodes.stats
	#	 									 nNoAdapter              0
	#                                            nNoUMI              0
	#                                             nNoCB              0
	#                                            nNinCB              0
	#                                           nNinUMI              0
	#                                   nUMIhomopolymer          19697
	#                                          nTooMany              0
	#                                          nNoMatch        1720635
	#                               nMismatchesInMultCB              0
	#                                       nExactMatch       36189052
	#                                    nMismatchOneWL        1828912
	#                                 nMismatchToMultWL              0

# Inspect alignment statistics.
less /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Log.final.out
	# Uniquely mapped reads % | 71.84%
	
# Extract selected metrics into a compact summary.
grep -E 'Number of input reads|Uniquely mapped reads %|% of reads mapped to multiple loci|% of reads unmapped' /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Log.final.out
# 						   Number of input reads |       39758296
#                        Uniquely mapped reads % |       71.84%
#             % of reads mapped to multiple loci |       0.00%
#       % of reads unmapped: too many mismatches |       0.00%
#                 % of reads unmapped: too short |       4.78%
#                     % of reads unmapped: other |       0.18%

# Locate the STARsolo count matrices.
ls -lh /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Solo.out/Gene/raw/

# Inspect dimensions without converting to a dense matrix. 
# Choose the 1MM_Directional matrix which represents UMI counts after directional correction, so it does not include the UMI douplications.
head /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Solo.out/Gene/raw/umiDedup-1MM_Directional.mtx
wc -l /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Solo.out/Gene/raw/features.tsv
wc -l /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Solo.out/Gene/raw/barcodes.tsv

# Create the R conversion script.
# First check that R and the required packages are available.
R --version
Rscript -e "library(Matrix); library(data.table); sessionInfo()"

# Make an empty script.
touch /scratch/Omics_in_practice/aspantidaki/projects/brbseq/scripts/convert_matrix.sh

# Paste the script below in it.
nano convert_matrix.sh

# This corrected version uses file.path so that paths do not depend on a trailing slash and quotes the output filename properly.
library(Matrix)
library(data.table)

matrix_dir <- "/scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/starsolo/Solo.out/Gene/raw"
output_file <- "/scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/umi_counts.txt"

mat_sparse <- readMM(file.path(matrix_dir, "umiDedup-1MM_Directional.mtx"))

features <- fread(
    file.path(matrix_dir, "features.tsv"),
    header = FALSE,
    data.table = FALSE
)

barcodes <- fread(
    file.path(matrix_dir, "barcodes.tsv"),
    header = FALSE,
    data.table = FALSE
)

stopifnot(nrow(mat_sparse) == nrow(features))
stopifnot(ncol(mat_sparse) == nrow(barcodes))

mat <- as.data.frame(as.matrix(mat_sparse))

colnames(mat) <- barcodes[[1]]
rownames(mat) <- features[[1]]

fwrite(
    mat,
    file = output_file,
    sep = "\t",
    quote = FALSE,
    row.names = TRUE,
    col.names = TRUE
)

message("Wrote: ", output_file)

# Make it executable. 
chmod +x /scratch/Omics_in_practice/aspantidaki/projects/brbseq/scripts/convert_matrix.sh

# Run the script from the project root so its relative paths resolve correctly.
cd /scratch/Omics_in_practice/aspantidaki/projects/brbseq
Rscript /scratch/Omics_in_practice/aspantidaki/projects/brbseq/scripts/convert_matrix.sh 2>&1 | tee /scratch/Omics_in_practice/aspantidaki/projects/brbseq/logs/convert_matrix.log

# Check that the output was created.
ls -lh /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/umi_counts.txt

# Inspect and validate the final matrix.
# Inspect only the beginning of the file. 
# Avoid opening a very large matrix directly in a spreadsheet application.
head -n 5 /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/umi_counts.txt | cut -f1-6

	#           AACAACCGAAGTAA  AACAGGATAACTCC  AACCATCGCATCCA  AACTAGTATCCGGA  ACAATAGGTGGTCC
	# ENSG00000290825.2       0       0       0       0       0
	# ENSG00000223972.6       0       0       0       0       0
	# ENSG00000310526.1       0       0       0       0       0
	# ENSG00000227232.6       0       0       0       0       0

	# Rows represent genes or other annotated features.
	# Columns represent barcodes/samples.
	# Values represent counts for a gene-barcode combination.
	# The first row contains barcode names; the first column contains feature identifiers.

# Count rows and columns:
awk -F '\t' 'NR==1 {print "Columns including row-name field:", NF} END {print "Lines including header:", NR}' /scratch/Omics_in_practice/aspantidaki/projects/brbseq/results/umi_counts.txt
	# Columns including row-name field: 25
	# Lines including header: 78900

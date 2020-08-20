#!/bin/bash
set -euo pipefail

# Christopher Medway AWMGS
# runs FASTQC for R1 & R2 for given sample/lane

seqId=$1
sampleId=$2
laneId=$3

echo "Running FASTQC"

mkdir -p FASTQC

# consider adding --adapter to command
fastqc \
    --dir ./tmpdir \
    --threads 20 \
    --extract \
    --quiet \
    "$seqId"_"$sampleId"_"$laneId"_R1.fastq \
    "$seqId"_"$sampleId"_"$laneId"_R2.fastq

mv "$seqId"_"$sampleId"_"$laneId"_R1_fastqc/summary.txt "$seqId"_"$sampleId"_"$laneId"_R1_fastqc.txt
mv "$seqId"_"$sampleId"_"$laneId"_R2_fastqc/summary.txt	"$seqId"_"$sampleId"_"$laneId"_R2_fastqc.txt

rm -r "$seqId"_"$sampleId"_"$laneId"_R1_fastqc/
rm -r "$seqId"_"$sampleId"_"$laneId"_R2_fastqc/
rm "$seqId"_"$sampleId"_"$laneId"_R1_fastqc.zip
rm "$seqId"_"$sampleId"_"$laneId"_R2_fastqc.zip

mv *fastqc* ./FASTQC/


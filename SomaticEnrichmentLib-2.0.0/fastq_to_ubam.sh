#!/bin/bash
set -euo pipefail

# Christopher Medway AWMGS
# generates uBAM from R1 and R2 reads for a given sample / lane

seqId=$1
sampleId=$2
laneId=$3
worklistId=$4
panel=$5
expectedInsertSize=$6

echo "converting fastq to ubam"

picard \
    FastqToSam \
    F1="$seqId"_"$sampleId"_"$laneId"_R1.fastq \
    F2="$seqId"_"$sampleId"_"$laneId"_R2.fastq \
    O="$seqId"_"$sampleId"_"$laneId"_unaligned.bam \
    QUALITY_FORMAT=Standard \
    READ_GROUP_NAME="$seqId"_"$sampleId"_"$laneId" \
    SAMPLE_NAME="$sampleId" \
    LIBRARY_NAME="$worklistId"_"$sampleId"_"$panel" \
    PLATFORM_UNIT="$seqId"_"$sampleId"_"$laneId" \
    PLATFORM="ILLUMINA" \
    SEQUENCING_CENTER="IMG" \
    PREDICTED_INSERT_SIZE="$expectedInsertSize" \
    SORT_ORDER=queryname \
    MAX_RECORDS_IN_RAM=2000000 \
    TMP_DIR=./tmpdir \
    RUN_DATE=`date +%s` \
    QUIET=true \
    VERBOSITY=ERROR

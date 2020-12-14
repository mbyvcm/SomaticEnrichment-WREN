#!/bin/bash
set -euo pipefail

# Christopher Medway AWMGS
# generation of PICARD metrics for each sample 

seqId=$1
sampleId=$2
panel=$3
minimumCoverage=$4
vendorCaptureBed=$5
vendorPrimaryBed=$6
padding=$7
minBQS=$8
minMQS=$9

JAVA_OPTIONS="-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Djava.io.tmpdir=./tmpdir -Xmx2g"

#Convert capture BED to interval_list for later
picard "$JAVA_OPTIONS" BedToIntervalList \
    I=$vendorCaptureBed \
    O="$panel"_capture.interval_list \
    SD=/home/transfer/resources/human/gatk/2.8/b37/human_g1k_v37.dict

#Convert primary BED to interval_list for later
picard "$JAVA_OPTIONS" BedToIntervalList \
    I=$vendorPrimaryBed \
    O="$panel"_primary.interval_list \
    SD=/home/transfer/resources/human/gatk/2.8/b37/human_g1k_v37.dict

#Alignment metrics: library sequence similarity
picard "$JAVA_OPTIONS" CollectAlignmentSummaryMetrics \
    R=/home/transfer/resources/human/gatk/2.8/b37/human_g1k_v37.fasta \
    I="$seqId"_"$sampleId".bam \
    O="$seqId"_"$sampleId"_AlignmentSummaryMetrics.txt \
    MAX_RECORDS_IN_RAM=2000000 \
    TMP_DIR=./tmpdir

#Calculate insert size: fragmentation performance
picard "$JAVA_OPTIONS" CollectInsertSizeMetrics \
    I="$seqId"_"$sampleId".bam \
    O="$seqId"_"$sampleId"_InsertMetrics.txt \
    H="$seqId"_"$sampleId"_InsertMetrics.pdf \
    MAX_RECORDS_IN_RAM=2000000 \
    TMP_DIR=./tmpdir

#HsMetrics: capture & pooling performance
picard "$JAVA_OPTIONS" CollectHsMetrics \
     I="$seqId"_"$sampleId".bam \
     O="$seqId"_"$sampleId"_HsMetrics.txt \
     R=/home/transfer/resources/human/gatk/2.8/b37/human_g1k_v37.fasta \
     BAIT_INTERVALS="$panel"_capture.interval_list \
     TARGET_INTERVALS="$panel"_primary.interval_list \
     MAX_RECORDS_IN_RAM=2000000 \
     TMP_DIR=./tmpdir \
     MINIMUM_MAPPING_QUALITY=$minMQS \
     MINIMUM_BASE_QUALITY=$minBQS \
     CLIP_OVERLAPPING_READS=false

#!/bin/bash
set -euo pipefail

# Christopher Medway AWMGS
# marks duplicated for all BAM files that have been generated for a sample
# merges across lanes

echo "removing duplicates and merging lanes"

seqId=$1
sampleId=$2

JAVA_OPTIONS="-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Djava.io.tmpdir=./tmpdir -Xmx2g"

picard "$JAVA_OPTIONS" \
    MarkDuplicates \
    $(ls "$seqId"_"$sampleId"_*_aligned.bam | \sed 's/^/I=/' | tr '\n' ' ') \
    OUTPUT="$seqId"_"$sampleId"_rmdup.bam \
    METRICS_FILE="$seqId"_"$sampleId"_markDuplicatesMetrics.txt \
    CREATE_INDEX=true \
    MAX_RECORDS_IN_RAM=2000000 \
    VALIDATION_STRINGENCY=SILENT \
    TMP_DIR=./tmpdir \
    QUIET=true \
    VERBOSITY=ERROR

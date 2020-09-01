#!/bin/bash
set -euo pipefail

# Christopher Medway AWMGS
# Applies filter flags to variant calls.
# Hard filters rare variants (<1%) and only keeps variants
# with PASS, germline_risk and/or clustered_event in FILTER column

seqId=$1
sampleId=$2
panel=$3
minBQS=$4
minMQS=$5
vendorPrimaryBed=$6

gatk --java-options "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Djava.io.tmpdir=./tmpdir -Xmx4g" \
    GetPileupSummaries \
    -V /home/transfer/resources/human/gnomad/gnomad.exomes.r2.0.1.sites.common.bialleleic.vcf.gz \
    -I "$seqId"_"$sampleId".bam \
    -O getpileupsummaries.table    

gatk --java-options "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Djava.io.tmpdir=./tmpdir -Xmx4g" \
    CalculateContamination \
    -I getpileupsummaries.table \
    -O calculateContamination.table

gatk --java-options "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Djava.io.tmpdir=./tmpdir -Xmx4g" \
    FilterMutectCalls \
    --variant "$seqId"_"$sampleId".vcf.gz \
    --contamination-table calculateContamination.table \
    --min-base-quality-score $minBQS \
    --min-median-mapping-quality $minMQS \
    --tumor-lod 4.7 \
    --output "$seqId"_"$sampleId"_filtered.vcf.gz \
    --verbosity ERROR \
    --QUIET true

gatk --java-options "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Djava.io.tmpdir=./tmpdir -Xmx4g" \
    CollectSequencingArtifactMetrics \
    -I "$seqId"_"$sampleId".bam \
    -O seqArtifacts \
    --FILE_EXTENSION ".txt" \
    -R /home/transfer/resources/human/gatk/2.8/b37/human_g1k_v37.fasta \
    --VERBOSITY ERROR \
    --QUIET true

gatk --java-options "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Djava.io.tmpdir=./tmpdir -Xmx4g" \
    FilterByOrientationBias \
    -AM G/T \
    -AM C/T \
    -V "$seqId"_"$sampleId"_filtered.vcf.gz \
    -P seqArtifacts.pre_adapter_detail_metrics.txt \
    -O "$seqId"_"$sampleId"_filteredStr.vcf.gz \
    --verbosity ERROR \
    --QUIET true

# split multialleleic calls onto separate line and filter SNVs / Indels < 1%
bcftools norm -m - "$seqId"_"$sampleId"_filteredStr.vcf.gz |
    bcftools filter -e 'AF < 0.01' |
    bcftools view -e 'FILTER="multiallelic" ||
        FILTER="str_contraction"    ||
        FILTER="t_lod"              ||
        FILTER="base_quality"       ||
        FILTER="strand_artifact"    ||
        FILTER="read_position"      ||
        FILTER="orientation_bias"   ||
        FILTER="mapping_quality"    ||
        FILTER="fragment_length"    ||
        FILTER="artifact_in_normal" ||
        FILTER="contamination"      ||
        FILTER="duplicate_evidence" ||
        FILTER="panel_of_normals"' > "$seqId"_"$sampleId"_filteredStrLeftAligned.vcf

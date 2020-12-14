#!/bin/bash

# Description: generate custom variant report given bedfile and vcffile
# Author: Christopher Medway, AWMGL

seqId=$1
sampleId=$2
panel=$3
pipelineName=$4
pipelineVersion=$5

# load conda env
source /home/transfer/.bashrc
module load anaconda
conda activate vcf_parse

# catch errors early
set -euo pipefail
    
mkdir -p hotspot_variants

python /data/diagnostics/apps/vcf_parse/vcf_parse-0.1.2/vcf_parse.py \
    --transcripts /data/diagnostics/pipelines/$pipelineName/"$pipelineName"-"$pipelineVersion"/$panel/"$panel"_PreferredTranscripts.txt \
    --transcript_strictness low \
    --config /data/diagnostics/pipelines/$pipelineName/"$pipelineName"-"$pipelineVersion"/$panel/"$panel"_ReportConfig.txt \
    --bed_folder /data/diagnostics/pipelines/$pipelineName/"$pipelineName"-"$pipelineVersion"/$panel/hotspot_variants/ \
    "$seqId"_"$sampleId"_filteredStrLeftAligned_annotated.vcf

set +u
conda deactivate
set -u

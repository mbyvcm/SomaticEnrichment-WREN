#!/bin/bash
set -euo pipefail

# Arthor: Christopjher Medway <christopher.medway@wales.nhs.uk>
# Description: Run MANTA over each sample for SV detection in tumor

seqId=$1
sampleId=$2
panel=$3
vendorPrimaryBed=$4

module load anaconda

if [ -d MANTA ]
then
    rm -r MANTA
fi

mkdir MANTA

set +u
source activate manta
set -u

cat $vendorPrimaryBed | bgzip > MANTA/callRegions.bed.gz
tabix -p bed MANTA/callRegions.bed.gz

configManta.py \
    --tumorBam "$seqId"_"$sampleId".bam \
    --referenceFasta /home/transfer/resources/human/gatk/2.8/b37/human_g1k_v37.fasta \
    --runDir  ./MANTA \
    --exome \
    --callRegions ./MANTA/callRegions.bed.gz

./MANTA/runWorkflow.py --quiet -m local

set +u
conda deactivate
set -u

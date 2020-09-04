#!/bin/bash

#SBATCH --time=12:00:00
#SBATCH --output=CNVKit-%N-%j.output
#SBATCH --error=CNVKit-%N-%j.error
#SBATCH --partition=high
#SBATCH --cpus-per-task=40

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

seqId=$2
panel=$3
sample=$4

$cnvkit coverage ./$sample/"$seqId"_"$sample".bam *.target.bed -o "$sample".targetcoverage.cnn
$cnvkit coverage ./$sample/"$seqId"_"$sample".bam *.antitarget.bed -o "$sample".antitargetcoverage.cnn

if [ -e "$sample".antitargetcoverage.cnn ]
then
    echo $sample >> samplesCNVKit_script1.txt
fi

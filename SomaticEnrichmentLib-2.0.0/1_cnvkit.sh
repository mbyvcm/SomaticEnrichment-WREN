#!/bin/bash

#SBATCH --time=12:00:00
#SBATCH --partition=high
#SBATCH --cpus-per-task=40

cd  "$SLURM_SUBMIT_DIR"

# load conda envs
. "$panel".variables
. ~/.bashrc
module load anaconda
conda activate $conda_cnvkit

# catch errors early
set -euo pipefail

cnvkit.py coverage ./$sample/"$seqId"_"$sample".bam *.target.bed -o "$sample".targetcoverage.cnn
cnvkit.py coverage ./$sample/"$seqId"_"$sample".bam *.antitarget.bed -o "$sample".antitargetcoverage.cnn

if [ -e "$sample".antitargetcoverage.cnn ]
then
    echo $sample >> samplesCNVKit_script1.txt
fi

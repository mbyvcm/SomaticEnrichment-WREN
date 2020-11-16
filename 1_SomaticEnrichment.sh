#!/bin/bash

#SBATCH --time=12:00:00
#SBATCH --output=SomaticEnrichment-%N-%j.output
#SBATCH --error=SomaticEnrichment-%N-%j.error
#SBATCH --partition=high
#SBATCH --cpus-per-task=40

# Description: Somatic Enrichment Pipeline. Requires fastq file split by lane
# Author:      AWMGS
# Mode:        BY_SAMPLE
# Use:         sbatch within sample directory

cd "$SLURM_SUBMIT_DIR"

version="2.0.0"

# load sample variables
. *.variables

# number of samples required later for CNV calling
numberSamplesInProject=$(find ../ -maxdepth 1 -mindepth 1 -type d | uniq | wc -l)

# copy library resources
pipeline_dir=/data/diagnostics/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"
cp -r "$pipeline_dir"/SomaticEnrichmentLib-"$version" .
cp "$pipeline_dir"/"$panel"/"$panel".variables .

# setup local scratch
SCRATCH_DIR=/localscratch/"$SLURM_JOB_ID"/"$seqId"/"$worklistId"/"$panel"/"$sampleId"
mkdir -p "$SCRATCH_DIR" && cd "$SCRATCH_DIR"

# setup temp dir
mkdir tmpdir

# link fastq / variables files to scratch
ln -s $SLURM_SUBMIT_DIR/* .

# load pipeline variables
. "$panel".variables

# path to panel capture bed file
vendorCaptureBed=/data/diagnostics/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/"$panel"/180702_HG19_PanCancer_EZ_capture_targets.bed
vendorPrimaryBed=/data/diagnostics/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/"$panel"/180702_HG19_PanCancer_EZ_primary_targets.bed

# activate conda env
module purge
module load anaconda
. ~/.bashrc
conda activate $conda_SE

# catch fails early and terminate
set -euo pipefail

# define fastq variables
for fastqPair in $(ls "$sampleId"_S*.fastq.gz | cut -d_ -f1-3 | sort | uniq)
do
    
    laneId=$(echo "$fastqPair" | cut -d_ -f3)
    read1Fastq=$(ls "$fastqPair"_R1_*fastq.gz)
    read2Fastq=$(ls "$fastqPair"_R2_*fastq.gz)

    # cutadapt
    ./SomaticEnrichmentLib-"$version"/cutadapt.sh \
        $seqId \
        $sampleId \
        $laneId \
        $read1Fastq \
        $read2Fastq \
        $read1Adapter \
        $read2Adapter

    # fastqc
    ./SomaticEnrichmentLib-"$version"/fastqc.sh $seqId $sampleId $laneId

     # fastq to ubam
    ./SomaticEnrichmentLib-"$version"/fastq_to_ubam.sh \
        $seqId \
        $sampleId \
        $laneId \
        $worklistId \
        $panel \
        $expectedInsertSize

    # bwa
    ./SomaticEnrichmentLib-"$version"/bwa.sh $seqId $sampleId $laneId
    
done

# merge & mark duplicate reads
./SomaticEnrichmentLib-"$version"/mark_duplicates.sh $seqId $sampleId 

# rename bam files
mv "$seqId"_"$sampleId"_rmdup.bam "$seqId"_"$sampleId".bam
mv "$seqId"_"$sampleId"_rmdup.bai "$seqId"_"$sampleId".bai

# post-alignment QC
./SomaticEnrichmentLib-"$version"/post_alignment_qc.sh \
    $seqId \
    $sampleId \
    $panel \
    $minimumCoverage \
    $vendorCaptureBed \
    $vendorPrimaryBed \
    $padding \
    $minBQS \
    $minMQS

# coverage calculations
./SomaticEnrichmentLib-"$version"/hotspot_coverage.sh \
    $seqId \
    $sampleId \
    $panel \
    $pipelineName \
    $pipelineVersion \
    $minimumCoverage \
    $vendorPrimaryBed \
    $padding \
    $minBQS \
    $minMQS

# variant calling
./SomaticEnrichmentLib-"$version"/mutect2.sh $seqId $sampleId $pipelineName $version $panel $padding $minBQS $minMQS $vendorPrimaryBed

# variant filter
./SomaticEnrichmentLib-"$version"/variant_filter.sh $seqId $sampleId $panel $minBQS $minMQS

# annotation
# check that there are called variants to annotate
if [ $(grep -v "#" "$seqId"_"$sampleId"_filteredStrLeftAligned.vcf | grep -v '^ ' | wc -l) -ne 0 ]; then
    ./SomaticEnrichmentLib-"$version"/annotation.sh $seqId $sampleId $panel
else
    mv "$seqId"_"$sampleId"_filteredStrLeftAligned.vcf "$seqId"_"$sampleId"_filteredStrLeftAligned_annotated.vcf
fi

# generate variant reports
./SomaticEnrichmentLib-"$version"/hotspot_variants.sh $seqId $sampleId $panel $pipelineName $pipelineVersion

# run manta for all samples except NTC
if [[ $sampleId != *'NTC'* ]]; then 
    ./SomaticEnrichmentLib-"$version"/manta.sh $seqId $sampleId $panel $vendorPrimaryBed
fi

# migrate data from scratch to results location
cp "$seqId"_"$sampleId"_filteredStrLeftAligned_annotated.vcf $SLURM_SUBMIT_DIR
if [ -e "$seqId"_"$sampleId"_filteredStrLeftAligned_annotated.vcf.idx ]; then cp "$seqId"_"$sampleId"_filteredStrLeftAligned_annotated.vcf.idx $SLURM_SUBMIT_DIR; fi
cp "$seqId"_"$sampleId"_filteredStr.vcf.gz $SLURM_SUBMIT_DIR
cp "$seqId"_"$sampleId"_filteredStr.vcf.gz.tbi $SLURM_SUBMIT_DIR
cp "$seqId"_"$sampleId".bam $SLURM_SUBMIT_DIR
cp "$seqId"_"$sampleId".bai $SLURM_SUBMIT_DIR
cp "$seqId"_"$sampleId"_HsMetrics.txt $SLURM_SUBMIT_DIR
cp "$seqId"_"$sampleId"_InsertMetrics.txt $SLURM_SUBMIT_DIR
cp "$seqId"_"$sampleId"_markDuplicatesMetrics.txt $SLURM_SUBMIT_DIR
cp "$seqId"_"$sampleId"_DepthOfCoverage.sample_summary $SLURM_SUBMIT_DIR
cp "$sampleId"_VariantReport.txt $SLURM_SUBMIT_DIR
cp "$seqId"_"$sampleId"_AlignmentSummaryMetrics.txt $SLURM_SUBMIT_DIR
cp -r hotspot_variants $SLURM_SUBMIT_DIR
cp -r hotspot_coverage_* $SLURM_SUBMIT_DIR
if [ -d MANTA ]; then cp -r MANTA $SLURM_SUBMIT_DIR; fi
cp -r FASTQC $SLURM_SUBMIT_DIR

cd $SLURM_SUBMIT_DIR

# add samplename to run-level file if vcf detected
if [ -e "$seqId"_"$sampleId"_filteredStrLeftAligned_annotated.vcf ]
then
    echo $sampleId >> ../sampleVCFs.txt    
fi

# ---------------------------------------------------------------------------------------------------------
#  RUN LEVEL ANALYSES
# ---------------------------------------------------------------------------------------------------------

numberSamplesInVcf=$(cat ../sampleVCFs.txt | uniq | wc -l)

# only the last sample to complete SNV calling will run the following
if [ $numberSamplesInVcf -eq $numberSamplesInProject ]
then

    # run cnv kit
    echo "running CNVKit as $numberSamplesInVcf samples have completed SNV calling"
    ./SomaticEnrichmentLib-"$version"/cnvkit.sh $seqId $panel $vendorPrimaryBed $version

    # move to run-level
    cd ../

    # generate worksheets
    ./$sampleId/SomaticEnrichmentLib-"$version"/make_variant_report.sh

    # pull all the qc data together and generate combinedQC.txt
    ./$sampleId/SomaticEnrichmentLib-"$version"/compileQcReport.sh $seqId $panel

    # tidy - remove scratch
    rm -r /localscratch/"$SLURM_JOB_ID"

else
    echo "not all samples have completed running. Finishing process for this sample."

    # tidy - remove scratch
    rm -r /localscratch/"$SLURM_JOB_ID"
fi

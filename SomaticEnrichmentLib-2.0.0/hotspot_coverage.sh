#!/bin/bash
set -euo pipefail

# Christopher Medway AWMGS
# Performs all the coverage calculation across the panel and hotspot regions at given depth(s)

seqId=$1
sampleId=$2
panel=$3
pipelineName=$4
pipelineVersion=$5
minimumCoverage=$6
vendorPrimaryBed=$7
padding=$8
minBQS=$9
minMQS=${10}

JAVA_OPTIONS="-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Djava.io.tmpdir=./tmpdir -Xmx2g"

# minimumCoverage to array COV
IFS=',' read -r -a COV <<< "${minimumCoverage}"

# add given padding to vendor bedfile
bedtools \
    slop \
    -i $vendorPrimaryBed \
    -b $padding \
    -g /data/diagnostics/apps/bedtools/bedtools-v2.29.1/genomes/human.hg19.genome > vendorPrimaryBed_100pad.bed

# generate per-base coverage: variant detection sensitivity
gatk --java-options "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Djava.io.tmpdir=./tmpdir -Xmx4g" \
    -T DepthOfCoverage \
    -R /home/transfer/resources/human/gatk/2.8/b37/human_g1k_v37.fasta \
    -I "$seqId"_"$sampleId".bam \
    -L vendorPrimaryBed_100pad.bed \
    -o "$seqId"_"$sampleId"_DepthOfCoverage \
    --countType COUNT_FRAGMENTS \
    --minMappingQuality $minMQS \
    --minBaseQuality $minBQS \
    -ct ${COV[0]} \
    --omitLocusTable \
    -rf MappingQualityUnavailable \
    -dt NONE

# reformat depth file
sed 's/:/\t/g' "$seqId"_"$sampleId"_DepthOfCoverage \
    | grep -v "^Locus" \
    | sort -k1,1 -k2,2n \
    | bgzip > "$seqId"_"$sampleId"_DepthOfCoverage.gz

# tabix index depth file
tabix -b 2 -e 2 -s 1 "$seqId"_"$sampleId"_DepthOfCoverage.gz

# loop over each depth threshold (i.e. 250x, 135x)
for depth in "${COV[@]}"
do
    echo $depth

    hscov_outdir=hotspot_coverage_"$depth"x

    # loop over referral bedfiles and generate coverage report 
    if [ -d /data/diagnostics/pipelines/$pipelineName/$pipelineName-$pipelineVersion/$panel/hotspot_coverage ];then

    mkdir -p $hscov_outdir

    source activate CoverageCalculatorPy

    for bedFile in /data/diagnostics/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/$panel/hotspot_coverage/*.bed; do

        name=$(echo $(basename $bedFile) | cut -d"." -f1)
        echo $name

        python /data/diagnostics/apps/CoverageCalculatorPy/CoverageCalculatorPy-v1.1.0/CoverageCalculatorPy.py \
            -B $bedFile \
            -D "$seqId"_"$sampleId"_DepthOfCoverage.gz \
            --depth $depth \
            --padding 0 \
            --groupfile /data/diagnostics/pipelines/$pipelineName/$pipelineName-$pipelineVersion/$panel/hotspot_coverage/"$name".groups \
            --outname "$sampleId"_"$name" \
            --outdir $hscov_outdir

        # remove header from gaps file
        if [[ $(wc -l < $hscov_outdir/"$sampleId"_"$name".gaps) -eq 1 ]]; then
            
            # no gaps
            touch $hscov_outdir/"$sampleId"_"$name".nohead.gaps
        else
            # gaps
            grep -v '^#' $hscov_outdir/"$sampleId"_"$name".gaps > $hscov_outdir/"$sampleId"_"$name".nohead.gaps
        fi

        rm $hscov_outdir/"$sampleId"_"$name".gaps

    done

    source deactivate


    # add hgvs nomenclature to gaps
    source activate bed2hgvs

    for gapsFile in $hscov_outdir/*genescreen.nohead.gaps $hscov_outdir/*hotspots.nohead.gaps; do

        name=$(echo $(basename $gapsFile) | cut -d"." -f1)
        echo $name

        python /data/diagnostics/apps/bed2hgvs/bed2hgvs-0.1.1/bed2hgvs.py \
            --config /data/diagnostics/apps/bed2hgvs/bed2hgvs-0.1.1/configs/cluster.yaml \
            --input $gapsFile \
            --output $hscov_outdir/"$name".gaps \
            --transcript_map /data/diagnostics/pipelines/$pipelineName/"$pipelineName"-"$pipelineVersion"/$panel/RochePanCancer_PreferredTranscripts.txt

        rm $hscov_outdir/"$name".nohead.gaps
    done
    
    source deactivate

    # combine all total coverage files
    if [ -f $hscov_outdir/"$sampleId"_coverage.txt ]; then rm $hscov_outdir/"$sampleId"_coverage.txt; fi
    cat $hscov_outdir/*.totalCoverage | grep "FEATURE" | head -n 1 >> $hscov_outdir/"$sampleId"_coverage.txt
    cat $hscov_outdir/*.totalCoverage | grep -v "FEATURE" | grep -vP "combined_\\S+_GENE" >> $hscov_outdir/"$sampleId"_coverage.txt
    rm $hscov_outdir/*.totalCoverage
    rm $hscov_outdir/*combined*

    fi

done

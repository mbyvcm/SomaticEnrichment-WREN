#!/bin/bash

#SBATCH --time=12:00:00
#SBATCH --partition=high
#SBATCH --cpus-per-task=40
#SBATCH -J "CNVKit-2"

cd "$SLURM_SUBMIT_DIR"

module load anaconda
source /home/transfer/.bashrc
conda activate cnvkit

set -euo pipefail


FASTA=/home/transfer/resources/human/gatk/2.8/b37/human_g1k_v37.fasta

odir=./$test_sample/CNVKit/ 

echo "generating references"
cnvkit.py reference $(cat $odir/tc.array) $(cat $odir/atc.array) --fasta $FASTA  -o "$odir"/"$test_sample".reference.cnn

echo "fixing ratios"
cnvkit.py fix "$test_sample".targetcoverage.cnn "$test_sample".antitargetcoverage.cnn "$odir"/"$test_sample".reference.cnn -o "$odir"/"$test_sample".cnr

set +u
conda activate SomaticEnrichment
set -u

echo "selecting common germline variants for CNV backbone"
gatk \
    --java-options "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Djava.io.tmpdir=./tmpdir -Xmx4g" \
    SelectVariants \
    -R $FASTA \
    -V ./$test_sample/"$seqId"_"$test_sample"_filteredStr.vcf.gz \
    --select-type-to-include SNP \
    -O "$odir"/"$test_sample"_common.vcf \
    --restrict-alleles-to BIALLELIC \
    --selectExpressions 'POP_AF > 0.01' \
    --selectExpressions 'POP_AF < 0.99'

set +u
conda deactivate
set -u

echo "segmentation"
cnvkit.py segment "$odir"/"$test_sample".cnr -m cbs -o "$odir"/"$test_sample".cns --vcf "$odir"/"$test_sample"_common.vcf --drop-low-coverage
cnvkit.py segmetrics -s "$odir"/"$test_sample".cn{s,r} -o "$odir"/"$test_sample".segmetrics.cns --ci

cnvkit.py call "$odir"/"$test_sample".segmetrics.cns -o "$odir"/"$test_sample".call.cns --vcf "$odir"/"$test_sample"_common.vcf -m threshold -t=-0.32,-0.15,0.14,0.26 --filter ci --center

cnvkit.py metrics "$test_sample".targetcoverage.cnn "$test_sample".antitargetcoverage.cnn "$odir"/"$test_sample".cnr -s "$odir"/"$test_sample".call.cns > "$odir"/"$test_sample".metrics
cnvkit.py scatter "$odir"/"$test_sample".cnr -s "$odir"/"$test_sample".call.cns -v "$odir"/"$test_sample"_common.vcf -o "$odir"/"$test_sample"-scatter.pdf
cnvkit.py breaks "$odir"/"$test_sample".cnr "$odir"/"$test_sample".call.cns > "$odir"/"$test_sample".breaks
cnvkit.py genemetrics "$odir"/"$test_sample".cnr -s "$odir"/"$test_sample".segmetrics.cns -m 3 -t 0.13 > "$odir"/"$test_sample".genemetrics
cnvkit.py genemetrics "$odir"/"$test_sample".cnr -m 3 -t 0.13 > "$odir"/"$test_sample".unsegmented.genemetrics
cnvkit.py sex "$odir"/"$test_sample".*.cnn "$odir"/"$test_sample".cnr "$odir"/"$test_sample".call.cns > "$odir"/"$test_sample".sex

# generate CNV report for each panel
mkdir -p ./$test_sample/hotspot_cnvs

for cnvfile in /data/diagnostics/pipelines/SomaticEnrichment/SomaticEnrichment-"$version"/RochePanCancer/hotspot_cnvs/*;do
    
    name=$(basename $cnvfile)
    echo $name

    if [ $name == '1p19q' ]; then

        cnvkit.py scatter "$odir"/"$test_sample".cnr \
            -s "$odir"/"$test_sample".cns \
            -v "$odir"/"$test_sample"_common.vcf \
            -c 1:0-249250621 \
            -o ./$test_sample/hotspot_cnvs/"$test_sample"_chromosome1-scatter.pdf

        cnvkit.py scatter "$odir"/"$test_sample".cnr \
            -s "$odir"/"$test_sample".cns \
            -v "$odir"/"$test_sample"_common.vcf \
            -c 19:0-59128983 \
            -o ./$test_sample/hotspot_cnvs/"$test_sample"_chromosome19-scatter.pdf

    else

        if [ -f ./$test_sample/hotspot_cnvs/"$test_sample"_"$name" ]; then
            rm ./$test_sample/hotspot_cnvs/"$test_sample"_"$name"
        fi

        # prepare output files
        head -n 1 "$odir"/"$test_sample".genemetrics >> ./$test_sample/hotspot_cnvs/"$test_sample"_"$name"

        while read gene; do
            echo $gene

            # check that gene contains an entry in genemetrics file
            if grep -qw $gene "$odir"/"$test_sample".genemetrics; then
                grep -w $gene "$odir"/"$test_sample".genemetrics >> ./$test_sample/hotspot_cnvs/"$test_sample"_"$name"
            fi
            
            cnvkit.py scatter "$odir"/"$test_sample".cnr \
                -s "$odir"/"$test_sample".cns \
                -v "$odir"/"$test_sample"_common.vcf \
                -g $gene \
                -o ./$test_sample/hotspot_cnvs/"$test_sample"_"$gene"-scatter.pdf

        done <$cnvfile

    fi

done

echo $test_sample >> samplesCNVKit_script2.txt

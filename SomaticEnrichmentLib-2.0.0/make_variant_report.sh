#!/bin/bash

# only required to reinstate location script executed from
sample=$1

. ~/.bashrc
module load anaconda
source activate VirtualHood

# navigate to run level
cd ../

set -euo pipefail

    for i in ./*/; do
       
        sampleId=$(basename $i)
	echo $sampleId

        if [ $sampleId == 'NTC' ] || [ $sampleId == 'tmpdir' ]; then
            echo "skipping $sampleId worksheet"
        else
            # load sample variables
            . ./$sampleId/"$sampleId".variables

            # check that referral is set, skip if not
            if [ -z "${referral:-}" ] || [ $referral == 'null' ]; then
                echo "$sampleId referral reason not set, skipping sample"
            else
                echo "$sampleId referral - $referral"
                python /data/diagnostics/apps/VirtualHood/VirtualHood-1.3.0/panCancer_report.py \
			--runid $seqId \
			--sampleid $sampleId \
			--worksheet $worklistId \
			--referral $referral \
			--path "$PWD"/ \
			--artefacts /data/temp/artefacts_lists/

                # unset variable to make sure if doesn't carry over to next sample
                unset referral sampleId seqId worklistId
            fi
        fi
    done

# return to original location before exit
cd $sample

conda deactivate


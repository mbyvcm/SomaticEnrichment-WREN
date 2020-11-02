#!/bin/bash

seqId=$1
panel=$2

. ~/.bashrc
module load anaconda
source activate VirtualHood

set -euo pipefail

    for i in ./*/; do
       
        sampleId=$(basename $i)
	echo $sampleId

        if [ $sampleId == 'NTC' ]; then
            echo "skipping $sampleId worksheet"
        else
            # load sample variables
            . ./$sampleId/"$sampleId".variables

            # check that referral is set, skip if not
            if [ -z "${referral:-}" ] || [ $referral == 'null' ]; then
                echo "$sampleId referral reason not set, skipping sample"
            else
                echo "$sampleId referral - $referral"
                python /data/diagnostics/apps/VirtualHood/VirtualHood-1.2.0/panCancer_report.py $seqId $sampleId $worklistId $referral

                # unset variable to make sure if doesn't carry over to next sample
                unset $referral
            fi
        fi
    done

conda deactivate


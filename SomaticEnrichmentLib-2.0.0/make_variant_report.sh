#!/bin/bash
set -euo pipefail

seqId=$1
panel=$2

module load anaconda

source activate VirtualHood

    for i in ./*/; do
        echo $i
        sampleId=$(basename $i)

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


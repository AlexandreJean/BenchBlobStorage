#!/bin/bash
for key in $(jq -r 'keys[]' $1)
do  
    if [[ $key =~ "list" ]]
    then
        for i in `seq 0 $(( $(jq -r ".$key | length" $1) - 1))`
        do
                eval "$key[$i]"=`jq -r ".$key[$i]" $1`
        done
    else
        eval "$key"=`jq -r ".$key" $1`
    fi
done
#!/bin/bash

NUMBER_STG_ACCOUNTs=$1
STG_ACCOUNT_PREFIX=$2
rg=$3
location=$4
OUTPUT_File=$5

for i in `seq -w 000 1 $((NUMBER_STG_ACCOUNTs - 1))`
do
	az storage account delete -n ${STG_ACCOUNT_PREFIX}${i} -g $rg -y 
done

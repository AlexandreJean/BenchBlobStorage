#!/bin/bash

## You can edit those values, make sure you create the resource group first.
NUMBER_STG_ACCOUNTs=$1
STG_ACCOUNT_PREFIX=$2
rg=$3
location=$4
OUTPUT_File=$5

start=$(date --utc -d "-2 hours" +%Y-%m-%dT%H:%M:%SZ)
end=$(date --utc -d "+1 year" +%Y-%m-%dT%H:%M:%SZ)

## This loop allows you to create up to 1000 storage accounts, dumps SAS Keys to the OUTPUT_File you've set on variable.
for i in `seq -w 000 1 $((NUMBER_STG_ACCOUNTs - 1))`
do
	check=$(az storage account check-name -n ${STG_ACCOUNT_PREFIX}${i} | jq -r '.nameAvailable')
	if [ $check == true ]
	then
		echo Creating stg account ${STG_ACCOUNT_PREFIX}$i 
		echo STG${i}=\"https://${STG_ACCOUNT_PREFIX}${i}.blob.core.windows.net/\"
		echo STG${i}=\"https://${STG_ACCOUNT_PREFIX}${i}.blob.core.windows.net/\" >> $OUTPUT_File
		az storage account create -n ${STG_ACCOUNT_PREFIX}${i} -g $rg -l $location --access-tier hot --kind BlobStorage >> logs_stogcreation.txt
		echo SAS${i}=\"?$(az storage account generate-sas --account-name ${STG_ACCOUNT_PREFIX}${i} --permissions rwl --output tsv --start $start --expiry $end --services b --resource-types sco)\" >> $OUTPUT_File
	else
		echo STG Name ${STG_ACCOUNT_PREFIX}${i} not available
	fi
done

#!/bin/bash

NUMBER_STG_ACCOUNTs=20
STG_ACCOUNT_PREFIX="validch2020"
OUTPUT_File="SAS.keys"
rg="testvalid"

for i in `seq -w 000 1 $((NUMBER_STG_ACCOUNTs - 1))`
do
	az storage account delete -n ${STG_ACCOUNT_PREFIX}${i} -g $rg -y 
done

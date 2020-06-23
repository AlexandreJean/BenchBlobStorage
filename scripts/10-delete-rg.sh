#!/bin/bash
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG

#read input json and create environment variables and source them
echo -e "Reading inputs inside ./inputs-variables.json"
. ./scripts/read_inputs.sh ./inputs-variables.json

echo cleaning up keyvault flag
az keyvault secret set --vault-name $key_vault --name lock --value 0
echo cleaning RG $resource_group
az group delete -g $resource_group -y --no-wait
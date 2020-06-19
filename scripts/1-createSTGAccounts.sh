#!/bin/bash
#set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG

#read input json and create environment variables and source them
echo -e "Reading inputs inside ./inputs-variables.json"
. ./scripts/read_inputs.sh ./inputs-variables.json
SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q"

workdir=0-azhpc-vmss
mkdir -p ./$workdir

#create rg in my sub
echo -e "Check existence of rg $resource_group"
ISRG=$(az group exists -n $resource_group)
if [ $ISRG == "false" ]
then
    echo -e "$resource_group RG does not exist so let me create it"
    az group create -n $resource_group -l $location >> ./$workdir/$workdir.log 2>/dev/null
fi

echo -e "Retrieve Public fqdn from vault"
headnode_fqdn=$(az network public-ip list -g $resource_group -o json | jq -r ".[0].dnsSettings.fqdn")

echo run generate_SAS Here :
./master/generate_SAS.sh $numSTGAccounts $STGAccountsPre $resource_group $location $OUTPutSAS

echo right place root dir ?
ls -l $OUTPutSAS
cat $OUTPutSAS

if [ $(cat $OUTPutSAS | wc -l) -gt 0 ]
then
    echo scp $OUTPutSAS to headnode :
    scp $SSH_ARGS -i ./hpcadmin_id_rsa $OUTPutSAS $admin_user@$headnode_fqdn:

    echo check presence of $OUTPutSAS on headnode :
    ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "ls -l $OUTPutSAS"
else
    echo $OUTPutSAS is empty.
fi

echo -e "\e[1;34m script done, bye\033[0m"
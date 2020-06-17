#!/bin/bash
set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG

#read input json and create environment variables and source them
echo -e "Reading inputs inside ./inputs-variables.json"
. ./scripts/read_inputs.sh ./inputs-variables.json

workdir=0-azhpc-slurm
mkdir -p ./$workdir

#create rg in my sub
echo -e "Check existence of rg $resource_group"
ISRG=$(az group exists -n $resource_group)
if [ $ISRG == "false" ]
then
    echo -e "$resource_group RG does not exist so let me create it"
    az group create -n $resource_group -l $location >> ./$workdir/$workdir.log 2>/dev/null
fi

echo -e "Install azhpc"
#init az-hpc
. ./azurehpc/install.sh

cp -a azurehpc/tree/master/examples/slurm_autoscale $workdir

cd $workdir
cp -f ../${admin_user}_id_rsa* .
chmod 600 ${admin_user}_id_rsa*
ls -lart

#echo cleaning RG $resource_group
#az group delete -g $resource_group -y
echo -e "\e[1;34m script done, ciao bye\033[0m"
echo "------"

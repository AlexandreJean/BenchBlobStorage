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

echo -e "Config azhpc" 
echo -e "vnet=$vnet,location=$location,resource_group=$resource_group,admin_user=$admin_user,key_vault=$key_vault,install_from=$install_from"
azhpc-init -c ./config \
          -d  $workdir \
          -v vnet=$vnet,location=$location,resource_group=$resource_group,admin_user=$admin_user,key_vault=$key_vault,install_from=$install_from


cd $workdir
cp -f ../${admin_user}_id_rsa* .
chmod 600 ${admin_user}_id_rsa*
cp -a ../azurehpc/scripts .
cp -a ../azurehpc/examples/slurm_autoscale/scripts .

ls -l config.json
ls -l scripts/*.sh

echo -e "azhpc-build :"
azhpc-build -c config.slurmcluster.json

echo cleaning RG $resource_group
az group delete -g $resource_group -y
echo -e "\e[1;34m script done, ciao bye\033[0m"
echo "------"

#!/bin/bash
#set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG

#read input json and create environment variables and source them
echo -e "Reading inputs inside ./inputs-variables.json"
. ./scripts/read_inputs.sh ./inputs-variables.json

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

echo -e "Install azhpc"
#init az-hpc
. ./azurehpc/install.sh

echo -e "Config azhpc" 
azhpc-init -c ./config \
          -d vmsscluster \
          -v vnet=$vnet,location=$location,resource_group=$resource_group,admin_user=$admin_user,key_vault=$key_vault,install_from=$install_from,instances=$numIONodes,compute_vm_type=$ionodestype

chmod 600 ${admin_user}_id_rsa*
cd vmsscluster
cp -f ../${admin_user}_id_rsa* .
echo copy new scripts
mkdir scripts
cp ../execute/[123]-*.sh scripts/

echo -e "azhpc-build :"
azhpc-build -c config.vmsscluster.json

echo -e "\e[32m$(date +'[%F %T]') \e[1;32mOpen port 3000\033[0m"
az network nsg rule create -g $resource_group --nsg-name ${install_from}_nsg --access allow --priority 3000 --name grafana --description "Grafana Web" --source-port-range '*' --destination-port-range 3000 --destination-address-prefixes '*' --protocol Tcp 2>&1>/dev/null

echo -e "\e[32m$(date +'[%F %T]') \e[1;32mAdd Public fqdn to vault (grafanaurl)\033[0m"
fqdn=$(az network public-ip list -g $resource_group -o json | jq -r ".[0].dnsSettings.fqdn")
az keyvault secret set --vault-name $key_vault --name grafanaurl --value $fqdn 2>&1>/dev/null
privip=$(az network nic show -g $resource_group --name ${install_from}_nic | jq -r ".ipConfigurations[0].privateIpAddress")
az keyvault secret set --vault-name $key_vault --name grafanaprivip --value $privip 2>&1>/dev/null
password=$(az keyvault secret show --name grafanapwd --vault-name devopsvaulthusiana | jq -r ".value")

echo -e "\e[32m$(date +'[%F %T]') \e[1;32mSo now you can access it:\033[0m"
echo -e "\e[32m$(date +'[%F %T]') \e[1;32mURL\033[0m : "http://$fqdn:3000
echo -e "\e[32m$(date +'[%F %T]') \e[1;32mUSR\033[0m : "admin
echo -e "\e[32m$(date +'[%F %T]') \e[1;32mPWD\033[0m : "$password
echo -e "\e[32m$(date +'[%F %T]') \e[1;32mSSH\033[0m : "ssh -i .ssh/id_rsa $admin_user@$fqdn

echo -e "\e[1;34m script done, bye\033[0m"
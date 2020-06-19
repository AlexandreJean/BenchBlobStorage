#!/bin/bash
#set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG

#read input json and create environment variables and source them
echo -e "Reading inputs inside ./inputs-variables.json"
. ./scripts/read_inputs.sh ./inputs-variables.json
SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q"

echo -e "Retrieve Public fqdn from vault"
headnode_fqdn=$(az network public-ip list -g $resource_group -o json | jq -r ".[0].dnsSettings.fqdn")

# Create nodelist file :
echo nodelist.txt creation
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute /sbin/ifconfig eth0" | awk '{if ($0 ~ /inet /) {print $2}}' | cut -d "." -f 3,4 | sed 's/\.//' | sort -n > nodelist.txt
scp $SSH_ARGS -i ./hpcadmin_id_rsa nodelist.txt $admin_user@$headnode_fqdn:
cat nodelist.txt


# if [ $(cat $OUTPutSAS | wc -l) -gt 0 ]
# then
#     echo scp $OUTPutSAS to headnode :
#     scp $SSH_ARGS -i ./hpcadmin_id_rsa $OUTPutSAS $admin_user@$headnode_fqdn:

#     echo check presence of $OUTPutSAS on headnode :
#     ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "ls -l $OUTPutSAS"
# else
#     echo $OUTPutSAS is empty.
# fi



echo -e "\e[1;34m script done, bye\033[0m"
#!/bin/bash
#set -e

# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG

#read input json and create environment variables and source them
echo -e "Reading inputs inside ./inputs-variables.json"
. ./scripts/read_inputs.sh ./inputs-variables.json
SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q"

export LC_ALL=C

echo -e "Retrieve Public fqdn from vault"
headnode_fqdn=$(az network public-ip list -g $resource_group -o json | jq -r ".[0].dnsSettings.fqdn")

# Create nodelist file :
echo nodelist.txt creation
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute /sbin/ifconfig eth0" | awk '{if ($0 ~ /inet /) {print $3}}' | cut -d "." -f 3,4 | sed 's/\.//' | sort -n > nodelist.txt
scp $SSH_ARGS -i ./hpcadmin_id_rsa nodelist.txt $admin_user@$headnode_fqdn:/share/data/

# Cleanup iozone files from nodes if present
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute sudo rm -f /mnt/resource/iozone*"

# Copy write / read /taskset scripts to headnode
scp $SSH_ARGS -i ./hpcadmin_id_rsa execute/[45]*.sh $admin_user@$headnode_fqdn:/share/data/
scp $SSH_ARGS -i ./hpcadmin_id_rsa execute/taskset.sh $admin_user@$headnode_fqdn:/share/data/

# Now have to run reads.sh - are scripts present ?
echo check if scripts are present :
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute 'ls -lart /data/' | dshbak -c"
cpucnt=$(ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute cat /proc/cpuinfo" | awk '{if ($0 ~ /processor/) {print $1}}' | sort  | uniq -c | awk '{print $1}' | head -1)

# Ideally here I'd need to have network bandwidth of the type of node benchmarked so I can load the stg accounts properly.

# Start downloading files from Azure storage accounts :
echo start download from stg accounts :
div=$(( $numIONodes / $numSTGAccounts ))
nbfiles=$(( $cpucnt / 4 ))
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute 'sh /data/5-reads.sh $numSTGAccounts $((div - 1)) $nbfiles $readIterations'"

echo -e "\e[1;34m script done, bye\033[0m"
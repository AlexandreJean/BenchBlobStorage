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

echo Finish config Grafana
dashboard_dir=/var/lib/grafana/dashboards/
scp $SSH_ARGS -i ./hpcadmin_id_rsa master/disksadls_v1.json $admin_user@$headnode_fqdn:/tmp/
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "sudo cp /tmp/disksadls_v1.json $dashboard_dir"
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "sudo systemctl stop grafana-server"
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "sudo systemctl start grafana-server"

# Create nodelist file :
echo nodelist.txt creation
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute /sbin/ifconfig eth0" | awk '{if ($0 ~ /inet /) {print $3}}' | cut -d "." -f 3,4 | sed 's/\.//' | sort -n > nodelist.txt
scp $SSH_ARGS -i ./hpcadmin_id_rsa nodelist.txt $admin_user@$headnode_fqdn:/share/data/

# Cleanup iozone files from nodes if present
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute sudo rm -f /mnt/resource/iozone*"

# Run iozone :
echo What is /mnt/resource size ?
disksz=$(ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute /bin/df /mnt/resource" | awk '{if ($0 ~ /resource/) {print $5}}' | sort -n | head -1)
filesz=$(($disksz*80/100/1024/1024))

memsz=$(ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute cat /proc/meminfo" | awk '{if ($0 ~ / MemTotal/) {print $3/1024/2014}}' | cut -d "." -f 1 | uniq)
cpucnt=$(ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute cat /proc/cpuinfo" | awk '{if ($0 ~ /processor/) {print $1}}' | sort  | uniq -c | awk '{print $1}' | head -1)

echo DISK Size = ${disksz}B
echo file size = ${filesz}GB
echo Mem Size  = ${memsz}GB

if [ $(( $memsz * 2 )) -lt $filesz ]
then
    filesz=$(( $memsz * 2 ))
fi

echo Using only ${filesz}GB

echo Create empty files in /mnt/resource directory
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute 'cd /mnt/resource; iozone -i 0 -i 1 -+n -r 1M -t 1 -s ${filesz}g -w | grep \"Children see throughput for\"'"

# Copy write script to headnode
scp $SSH_ARGS -i ./hpcadmin_id_rsa execute/[45]*.sh $admin_user@$headnode_fqdn:/share/data/

# Now have to run writes.sh - are scripts present ?
echo check if scripts are present :
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute 'ls -lart /data/' | dshbak -c"

# Ideally here I'd need to have network bandwidth of the type of node benchmarked so I can load the stg accounts properly.

# Start uploading files to Azure storage accounts :
echo start upload to stg accounts :
div=$(( $numIONodes / $numSTGAccounts ))
nbfiles=$(( $cpucnt / 4 ))
echo cpucount = $cpucnt
echo nbfiles = $nbfiles

ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute 'sh /data/4-writes.sh $numSTGAccounts $((div - 1)) $filesz $nbfiles'"

echo -e "\e[1;34m script done, bye\033[0m"
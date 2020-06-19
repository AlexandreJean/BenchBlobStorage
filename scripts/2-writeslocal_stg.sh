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
scp $SSH_ARGS -i ./hpcadmin_id_rsa master/disksadls_v1.json $admin_user@$headnode_fqdn:$dashboard_dir
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "sudo systemctl stop grafana-server"
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "systemctl start grafana-server"

# Create nodelist file :
echo nodelist.txt creation
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute /sbin/ifconfig eth0" | awk '{if ($0 ~ /inet /) {print $3}}' | cut -d "." -f 3,4 | sed 's/\.//' | sort -n > nodelist.txt
scp $SSH_ARGS -i ./hpcadmin_id_rsa nodelist.txt $admin_user@$headnode_fqdn:

# Cleanup iozone files from nodes if present
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute sudo rm -f /mnt/resource/iozone*"

# Run iozone :
echo What is /mnt/resource size ?
disksz=$(ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute /bin/df /mnt/resource" | awk '{if ($0 ~ /resource/) {print $5}}' | sort -n | head -1)
filesz=$(($disksz*80/100/1024/1024))
# Temporary
filesz=$(($disksz*10/100/1024/1024))
echo DISK Size = $disksz - Using only ${filesz}GB

echo Create empty files in /mnt/resource directory
# [hpcadmin@compute000001 resource]$ iozone -i 0 -i 1 -+n -r 1M -t 1 -s 1g -w | grep "Children see throughput for"
#         Children see throughput for  1 initial writers  = 1680825.12 kB/sec
#         Children see throughput for  1 readers          = 6907209.00 kB/sec
ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute 'cd /mnt/resource; iozone -i 0 -i 1 -+n -r 1M -t 1 -s ${filesz}g -w | grep \"Children see throughput for\"'"

# Copy write script to headnode
scp $SSH_ARGS -i ./hpcadmin_id_rsa execute/[45]*.sh $admin_user@$headnode_fqdn:/share/data/

ssh $SSH_ARGS -i ./hpcadmin_id_rsa $admin_user@$headnode_fqdn "pdsh -f $numIONodes -w ^azhpc_install_config.vmsscluster/hostlists/compute 'ls -lart /data/'

echo -e "\e[1;34m script done, bye\033[0m"
#!/bin/bash

. /data/SAS.keys 

STGAcounts=$1
indent=$2

ID=`/usr/sbin/ifconfig eth0 | awk '{if ($0 ~ /inet /) {print $2}}' | cut -d "." -f 3,4`
ID2=`echo $ID | sed 's/\.//'`
CONTAINER="input01-"$ID2
SRC="/mnt/resource/"
IPidx=1

##Loop on Storage accounts :
for i in `seq -w 000 $STGAcounts`
do
	stg="STG$i"
	sas="SAS$i"
	hoststart=`head -n $(( 10#$i + $IPidx )) /data/nodelist.txt | tail -1`
	IPidx=$(( $IPidx + $indent ))
	hostend=`head -n $(( 10#$i + $IPidx )) /data/nodelist.txt | tail -1`

	##Loop on number of files to read from the storage accounts :
	THR=0
	for j in `seq 0 3`
	do
		if [[ $ID2 -ge $hoststart && $ID2 -le $hostend ]]
		then
			echo $((THR))-$((THR+3)) azcopy copy ${!stg}$CONTAINER/iozone.DUMMY.${j}${!sas} /dev/null
		fi
		THR=$THR+4
	done | parallel /data/taskset.sh {} 
done

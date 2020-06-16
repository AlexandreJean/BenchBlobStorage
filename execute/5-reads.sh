#!/bin/bash

. /mnt/exports/shared/home/husiana/BenchBlobStorage/master/SAS.keys 

ID=`/usr/sbin/ifconfig eth0 | awk '{if ($0 ~ /inet /) {print $2}}' | cut -d "." -f 3,4`
ID2=`echo $ID | sed 's/\./-/'`
CONTAINER="input01-"$ID2
SRC="/mnt/resource/"
IPidx=1

##Loop on Storage accounts :
for i in `seq -w 000 004`
do
	stg="STG$i"
	sas="SAS$i"
	host1=`head -n $(( 10#$i + $IPidx )) /mnt/exports/shared/home/husiana/BenchBlobStorage/execute/nodelist.txt | tail -1`
	IPidx=$(( $IPidx + 1 ))
	host2=`head -n $(( 10#$i + $IPidx )) /mnt/exports/shared/home/husiana/BenchBlobStorage/execute/nodelist.txt | tail -1`

	##Loop on number of files to read from the storage accounts :
	THR=0
	for j in `seq 0 1`
	do
		if [ $ID == $host1 ] || [ $ID == $host2 ]
		then
			echo $((THR))-$((THR+3)) azcopy copy ${!stg}$CONTAINER/iozone.DUMMY.${j}${!sas} /dev/null
		fi
		THR=$THR+4
	done | parallel /mnt/exports/shared/home/husiana/BenchBlobStorage/execute/taskset.sh {} 
done

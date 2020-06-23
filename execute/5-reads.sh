#!/bin/bash

# Sourcing SAS.keys created earlier with stg accounts
. /data/SAS.keys 

STGAcounts=$1
indent=$2
nbfiles=$3

ID=`/usr/sbin/ifconfig eth0 | awk '{if ($0 ~ /inet /) {print $2}}' | cut -d "." -f 3,4`
ID2=`echo $ID | sed 's/\.//'`
CONTAINER="input01-"$ID2
SRC="/mnt/resource/"
IPidx=1

##Loop on Storage accounts :
for i in `seq -w 000 $((STGAcounts - 1))`
do
	stg="STG$i"
	sas="SAS$i"
	hoststart=`head -n $(( 10#$i + $IPidx )) /data/nodelist.txt | tail -1`
	IPidx=$(( $IPidx + $indent ))
	hostend=`head -n $(( 10#$i + $IPidx )) /data/nodelist.txt | tail -1`

	##Loop on number of files to read from the storage accounts :
	##4 x THR per azcopy task seems like a good option.
	THR=0
	for cnt in `seq 0 1`
	do
		for j in `seq 0 $(( $nbfiles - 1 ))`
		do
			if [[ $ID2 -ge $hoststart && $ID2 -le $hostend ]]
			then
				echo taskset -c $((THR))-$((THR+3)) azcopy copy ${!stg}$CONTAINER/iozone.DUMMY.${j}${!sas} /dev/null >> joblist-$$.txt
			fi
			THR=$THR+4
		done
	done | parallel -j $(( $nbfiles - 1 )) :::: joblist-$$.txt 
done
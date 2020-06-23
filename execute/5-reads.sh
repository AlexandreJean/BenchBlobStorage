#!/bin/bash

# Sourcing SAS.keys created earlier with stg accounts
. /data/SAS.keys 

STGAcounts=$1
indent=$2
nbfiles=$3
Iterations=$4

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
	array=()
	for cnt in `seq 1 $Iterations`
	do
		THR=0
		for j in `seq 0 $(( $nbfiles - 1 ))`
		do
			if [[ $ID2 -ge $hoststart && $ID2 -le $hostend ]]
			then
				if [[ $cnt -eq 0 ]]
				then
					array[$j]="taskset -c $((THR))-$((THR+3)) /usr/local/bin/azcopy copy \"${!stg}$CONTAINER/iozone.DUMMY.${j}${!sas}\" /dev/null;"
				elif [[ $cnt -lt $Iterations ]]
				then
					array[$j]=${array[$j]}"taskset -c $((THR))-$((THR+3)) /usr/local/bin/azcopy copy \"${!stg}$CONTAINER/iozone.DUMMY.${j}${!sas}\" /dev/null;"
				else
					array[$j]=${array[$j]}"taskset -c $((THR))-$((THR+3)) /usr/local/bin/azcopy copy \"${!stg}$CONTAINER/iozone.DUMMY.${j}${!sas}\" /dev/null"
				fi
			fi
			THR=$THR+4
		done
	done  
	for task in "${array[@]}"
	do
		echo $task >> joblist-$$.txt
	done
done | parallel -j $nbfiles :::: joblist-$$.txt

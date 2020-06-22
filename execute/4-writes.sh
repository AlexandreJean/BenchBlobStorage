#!/bin/bash

# Change this with the correct path where you stored your SAS.keys file during storage account creation
. /data/SAS.keys 

STGAcounts=$1
indent=$2
filesz=$3
nbfiles=$4

ID=`/usr/sbin/ifconfig eth0 | awk '{if ($0 ~ /inet /) {print $2}}' | cut -d "." -f 3,4`
ID2=`echo $ID | sed 's/\.//'`
CONTAINER="input01-"$ID2
SRC="/mnt/resource/"
IPidx=1

##Loop on Storage accounts :
# I'm looping on the 5 storage accounts I have created earlier

for i in `seq -w 000 $STGAcounts`
do
	stg="STG$i"
	sas="SAS$i"
	## Host1 is the first node for a storage account, starts at first line 
	hoststart=`head -n $(( 10#$i + $IPidx )) /data/nodelist.txt | tail -1`
	## If you wish to have 2 x nodes per storage account then increase by 1, if you want more nodes, incread by more than 1
	IPidx=$(( $IPidx + $indent ))
	## host2 is the last node for a storage account, ends at first line + IPidx
	hostend=`head -n $(( 10#$i + $IPidx )) /data/nodelist.txt | tail -1`

	##Loop on number of files to upload to the storage accounts :
	## We created a single large file, but we can upload it multiple times to the storage accounts so reads will be parallelized.
	## "0 1" will copy the files 2 times for example.
	for j in `seq 0 $(( $nbfiles - 1 ))`
	do
		if [[ $ID2 -ge $hoststart && $ID2 -le $hostend ]]
		then

	### DEBUG
	echo
	echo "------------------"
	echo host list :
	echo "   host1 : "$hoststart
	echo "   host2 : "$hostend
	echo STG Name: $stg
	echo STG Value : ${!stg}
	echo SAS Name: $sas
	echo SAS Value : ${!sas}
	echo "------------------"
	### DEBUG

			#echo start building Container on STG $i for $ID
			if [ $j == 0 ]
			then
				azcopy make ${!stg}$CONTAINER${!sas}
				azcopy copy ${SRC}iozone.DUMMY.0 ${!stg}$CONTAINER/iozone.DUMMY.${j}${!sas}
			else
				azcopy copy ${!stg}$CONTAINER/iozone.DUMMY.0${!sas} ${!stg}$CONTAINER/iozone.DUMMY.${j}${!sas} 
			fi
		fi
	done
	
	echo Have files been properly uploaded ?
	azcopy list ${!stg}${!sas} | awk -v size=$filesz '{if ($0 ~ /'"$size"'/) {print $2}}' | cut -d "/" -f 1 | sort | uniq -c

done
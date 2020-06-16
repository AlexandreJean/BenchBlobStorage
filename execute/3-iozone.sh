#!/bin/bash

wget -O /tmp/iozone.tar http://www.iozone.org/src/current/iozone3_489.tar
cd /tmp/
tar -xvf iozone.tar
cd iozone3_489/src/current/; make linux-AMD64; cp iozone /usr/local/bin/; chmod +x /usr/local/bin/iozone

echo Build files using iozone
cd /mnt/resource/
rm -f /mnt/resource/iozone*
iozone -i 0 -+n -r 1M -t 1 -s 100g -w | grep "Children see throughput for" 

#!/bin/bash

wget -O /tmp/iozone.tar http://www.iozone.org/src/current/iozone3_489.tar
cd /tmp/
tar -xvf iozone.tar
cd iozone3_489/src/current/; make linux-AMD64; cp iozone /usr/local/bin/; chmod +x /usr/local/bin/iozone

#!/bin/bash

# Install azcopy on compute nodes:
wget -O /tmp/azcp.tgz https://aka.ms/downloadazcopy-v10-linux
cd /tmp/
tar -xvzf azcp.tgz
cp /tmp/azcopy_linux_amd64_10.*/azcopy /usr/local/bin/
chmod +x /usr/local/bin/azcopy

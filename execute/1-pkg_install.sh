#! /bin/bash

yum -y install parallel fio iotop iftop screen git gcc

#Silence cite notification of parallel
echo "will cite\n" | parallel --citation

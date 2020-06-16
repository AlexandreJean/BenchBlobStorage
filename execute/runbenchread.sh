#!/bin/bash

NODELST=htc-[1-10]
NODECNT=10
CPUPTASK=16
PART="htc"

## Run the show from client nodes :
srun -l -p $PART -w $NODELST -N $NODECNT -t "2:10" --cpus-per-task $CPUPTASK -o ~/BenchBlobStorage/execute/logs/readlogs.txt sudo ~/BenchBlobStorage/execute/5-reads.sh

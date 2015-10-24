#!/bin/bash

TRACE_FOLDER="../paraver_traces/"
CONFIG_FILE="extrae.xml"
LIB_MPI_TRACE_PATH="/home/tiago/install/extrae-3.1.0/lib/libmpitrace.so"
NUM_PROCS=4
APPS=("allgather" "alltoallv" "gather" "sendrecv2" "allgatherv" "barrier" "gatherv" "reduce" "sendrecv3" "allreduce" "bcast" "reducescatter" "sendrecv4" "alltoall" "initfinalize" "sendrecv1")

make
export EXTRAE_CONFIG_FILE=$CONFIG_FILE
export LD_PRELOAD=/home/tiago/install/extrae-3.1.0/lib/libmpitrace.so
for i in "${APPS[@]}"; do
    echo "executing $i"
    mpirun -np $NUM_PROCS ./$i
done
unset EXTRAE_CONFIG_FILE
unset LD_PRELOAD
rm -r set-0
rm *.mpits
rm *.spawn
rm *.sym
mv *.pcf $TRACE_FOLDER
mv *.prv $TRACE_FOLDER
mv *.row $TRACE_FOLDER 
make clean

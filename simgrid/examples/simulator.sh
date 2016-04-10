#!/bin/bash

MACHINE_FILE=''
PLATFORM='griffon.xml'
SMPIRUN='smpirun'
REPLAY='../SimGrid-3.12/examples/smpi/smpi_replay'
OUTPUT='out.trace'
INPUT='sendrecv1.tit'

print_usage() {
    echo "Usage: $0 tit_trace [OPTIONS]"
    cat << 'End-of-message'
  -i | --input input file (tit trace)
  -o | --output output file
  -p | --platform XML platform file
  -m | --machine_file
  -h | --help print help information
End-of-message
    exit 1
}

TEMP=`getopt -o i:o:p:m:h --long input:,output:,platform:,machine_file:,help -n 'smpi2pj.sh' -- "$@"`
eval set -- "$TEMP"
while true; do
    case "$1" in
	-i|--input)
            case "$2" in
		"") shift 2;;
		*) INPUT=$2;shift 2;;
            esac;;
	-o|--output)
            case "$2" in
		"") shift 2;;
		*) OUTPUT=$2;shift 2;;
            esac;;
	-p|--platform)
            case "$2" in
		"") shift 2;;
		*) PLATFORM=$2;shift 2;;
            esac;;
	-m|--machine)
            case "$2" in
		"") shift 2;;
		*) MACHINE_FILE=$2;shift 2;;
            esac;;
	-h|--help)
            print_usage;shift;;
	--) shift; break;;
	*) echo "Unknown option '$1'"; print_usage;;
    esac
done

# separate the .tit file according to the task number
a=$(grep -Eo '^.' $INPUT | sort | tail -n 1)
ntasks=$((a+1))
i=0
while [ $i -lt $ntasks ]; do
    grep ^$i $INPUT > task$i.tit;
    i=$((i+1))
done

# create smpi replay input file
REPLAY_INPUT=smpi_replay.txt
ls task*.tit > $REPLAY_INPUT

# get the number of MPI ranks
export NP=$ntasks

# generating a dumb deployment (machine_file) if needed
if [ -z "$MACHINE_FILE" ]; then
    MACHINE_FILE=machine_file.txt;
    rm -f $MACHINE_FILE;
    touch $MACHINE_FILE;
    for i in `seq 1 144`; do
        echo griffon-${i}.nancy.grid5000.fr >> $MACHINE_FILE ;
    done
    cp $MACHINE_FILE $MACHINE_FILE.sav
    cat $MACHINE_FILE.sav $MACHINE_FILE.sav $MACHINE_FILE.sav $MACHINE_FILE.sav > $MACHINE_FILE
fi

# simulate
$SMPIRUN -ext smpi_replay --cfg=tracing/smpi/computing:'yes' --cfg=tracing/precision:9 --cfg=smpi/send_is_detached_thres:2 --cfg=smpi/async_small_thres:0 --cfg=smpi/cpu_threshold:-1 -trace --cfg=tracing/filename:$OUTPUT \
    -hostfile $MACHINE_FILE -platform $PLATFORM -np $NP $REPLAY $REPLAY_INPUT \
    --log=smpi_kernel.thres:warning --cfg=contexts/factory:thread 2>&1

# clean up
rm task*.tit
rm $REPLAY_INPUT
rm $MACHINE_FILE.sav
rm $MACHINE_FILE


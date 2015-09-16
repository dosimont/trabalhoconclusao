#!/bin/bash

MACHINE_FILE=$(cat <<'BABEL_TABLE'

BABEL_TABLE
)
PLATFORM=$(cat <<'BABEL_TABLE'
graphene.xml
BABEL_TABLE
)
SMPIRUN=$(cat <<'BABEL_TABLE'
smpirun
BABEL_TABLE
)
REPLAY=$(cat <<'BABEL_TABLE'
simgrid/examples/smpi/smpi_replay
BABEL_TABLE
)
OUTPUT=$(cat <<'BABEL_TABLE'
./bigdft_smpi_simgrid.trace
BABEL_TABLE
)
INPUT=$(cat <<'BABEL_TABLE'
out
BABEL_TABLE
)

print_usage()
{
    echo "Usage: $0 [OPTIONS]"
    cat <<'End-of-message'
  -i|--input Paraver input file
  -o|--output output file (in the paje format)
  -p|--platform XML platform file
  -m|--machine_file 
  -h|help print help information
End-of-message
 exit 1
}

TEMP=`getopt -o i:o:p:m:h --long input:,output:,platform:,machine_file:,help -n 'smpi2pj.sh' -- "$@"`
eval set -- "$TEMP"
while true;do 
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


TMP_WORKING_PATH=`mktemp -d`

# Creating input for smpi_replay
REPLAY_INPUT=$TMP_WORKING_PATH/smpi_replay.txt
ls $INPUT*.tit > $REPLAY_INPUT

# Get the number of MPI ranks
export NP=`cat $REPLAY_INPUT | wc -l`

# Generating a dumb deployment (machine_file) if needed
if [ -z "$MACHINE_FILE" ]; then
    MACHINE_FILE=$TMP_WORKING_PATH/machine_file.txt;
    if [ -e "$MACHINE_FILE" ]; then
        echo "Ooups $MACHINE_FILE already exists. Do not want to overwrite" ;
        exit 1 ;
    fi;
    rm -f $MACHINE_FILE;
    touch $MACHINE_FILE;
    for i in `seq 1 144`; do
        echo graphene-${i}.nancy.grid5000.fr >> $MACHINE_FILE ;
    done
    cp $MACHINE_FILE $MACHINE_FILE.sav
    cat $MACHINE_FILE.sav $MACHINE_FILE.sav $MACHINE_FILE.sav $MACHINE_FILE.sav > $MACHINE_FILE
fi

## To debug
# $SMPIRUN -ext smpi_replay --log=replay.thresh:critical --log=smpi_replay.thresh:verbose \
#          --cfg=smpi/cpu_threshold:-1  -hostfile machine_file -platform $PLATFORM \
#          -np $NP gdb\ --args\ $REPLAY /tmp/smpi_replay.txt  --log=smpi_kernel.thres:warning \
#          --cfg=contexts/factory:thread

$SMPIRUN -ext smpi_replay \
    --cfg=smpi/cpu_threshold:-1 -trace --cfg=tracing/filename:$OUTPUT \
    -hostfile $MACHINE_FILE -platform $PLATFORM -np $NP \
    $REPLAY $REPLAY_INPUT --log=smpi_kernel.thres:warning  \
    --cfg=contexts/factory:thread 2>&1 
# --log=replay.thresh:critical  --log=smpi_replay.thresh:verbose

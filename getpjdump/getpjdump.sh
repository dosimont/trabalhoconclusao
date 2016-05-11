#!/bin/bash

source config.conf

TRACE=$1
TRACE_NAME=$(basename $TRACE)

EXECDIR=$(pwd)
BASEDIR=$(dirname "$0")

#########################################################
# original trace

# create directory for storing original files
originaldir='original'
rm -r $BASEDIR'/'$originaldir
mkdir $BASEDIR'/'$originaldir

# copy the trace to this folder
cp $TRACE'.prv' $BASEDIR'/'$originaldir'/'$TRACE_NAME'.prv'
cp $TRACE'.pcf' $BASEDIR'/'$originaldir'/'$TRACE_NAME'.pcf'
cp $TRACE'.row' $BASEDIR'/'$originaldir'/'$TRACE_NAME'.row'

# change to the basedir directory
cd $BASEDIR

#########################################################
# dimemas simulation

# create directory for storing dimemas files
dimemasdir='dimemas'
rm -r $dimemasdir
mkdir $dimemasdir

# convert the prv trace to the dim format
./../dimemas/dimemas-5.2.12/prv2dim/prv2dim $originaldir'/'$TRACE_NAME.prv $dimemasdir'/'$TRACE_NAME.dim
echo 'prv trace converted to the dim format'

# create dimemas config file
cp 'platforms/'$PLATFORM_FILE'.cfg' $dimemasdir'/'$PLATFORM_FILE'-dimemas.cfg'
perl -pi -e 's/\$CORES\$/'$CORES'/g' $dimemasdir'/'$PLATFORM_FILE'-dimemas.cfg'
DIMEMAS_BANDWIDTH=$(echo 'scale=6; '$BANDWIDTH'/1000000' | bc)
perl -pi -e 's/\$BANDWIDTH\$/0'$DIMEMAS_BANDWIDTH'/g' $dimemasdir'/'$PLATFORM_FILE'-dimemas.cfg'
DIMEMAS_LATENCY=$(echo 'scale=6; '$LATENCY'/1' | bc)
perl -pi -e 's/\$LATENCY\$/0'$DIMEMAS_LATENCY'/g' $dimemasdir'/'$PLATFORM_FILE'-dimemas.cfg'
perl -pi -e 's/\$NTASKS\$/'$NTASKS'/g' $dimemasdir'/'$PLATFORM_FILE'-dimemas.cfg'
DIMEMAS_TASK_MAPPING=$(printf ",%s" "${TASK_MAPPING[@]}")
DIMEMAS_TASK_MAPPING=${DIMEMAS_TASK_MAPPING:1}
perl -pi -e 's/\$MAPPING\$/'$DIMEMAS_TASK_MAPPING'/g' $dimemasdir'/'$PLATFORM_FILE'-dimemas.cfg'
perl -pi -e 's/\$DIMFILE\$/'$TRACE_NAME'.dim/g' $dimemasdir'/'$PLATFORM_FILE'-dimemas.cfg'
DIMEMAS_RELATIVE_POWER=$(echo 'scale=6; '$SIMULATED_FLOPS'/'$ORIGINAL_FLOPS | bc)
perl -pi -e 's/\$POWER\$/0'$DIMEMAS_RELATIVE_POWER'/g' $dimemasdir'/'$PLATFORM_FILE'-dimemas.cfg'
echo 'created dimemas config file'

# dimemas simulation
cd dimemas
./../../dimemas/dimemas-5.2.12/Simulator/Dimemas $DIMEMAS_OPTS -p $TRACE_NAME-dimemas.prv $PLATFORM_FILE'-dimemas.cfg'
echo 'dimemas simulation is done'
cd ..

# convert the dimemas trace to pjdump
perl prv2pjdump.pl -i $dimemasdir'/'$TRACE_NAME-dimemas > $dimemasdir'/'$TRACE_NAME-dimemas.pjdump
echo 'got dimemas pjdump trace'

#########################################################
# simgrid simulation

# create directory for storing simgrid files
simgriddir='simgrid'
rm -r $simgriddir
mkdir $simgriddir

# convert the prv trace to the tit format
POWER_NS=$(echo 'scale=12; '$ORIGINAL_FLOPS'/1000000000' | bc)
perl prv2tit.pl -i $originaldir'/'$TRACE_NAME -p 0$POWER_NS > $simgriddir'/'$TRACE_NAME.tit
echo 'prv trace converted to the tit format'

# separate the tit file according to the task number
SIMGRID_INPUT=$simgriddir'/'$TRACE_NAME-smpi-replay.txt
touch $SIMGRID_INPUT
i=0
while [ $i -lt $NTASKS ]; do
    grep ^$i $simgriddir'/'$TRACE_NAME.tit > $simgriddir'/'task$i.tit;
    echo $simgriddir'/'task$i.tit >> $SIMGRID_INPUT
    i=$((i+1))
done

# create simgrid platform description
cp 'platforms/'$PLATFORM_FILE'.xml' $simgriddir'/'$PLATFORM_FILE'-simgrid.xml'
perl -pi -e 's/\$CORES\$/'$CORES'/g' $simgriddir'/'$PLATFORM_FILE'-simgrid.xml'
perl -pi -e 's/\$BANDWIDTH\$/'$BANDWIDTH'/g' $simgriddir'/'$PLATFORM_FILE'-simgrid.xml'
perl -pi -e 's/\$LATENCY\$/'$LATENCY's/g' $simgriddir'/'$PLATFORM_FILE'-simgrid.xml'
perl -pi -e 's/\$POWER\$/0'$SIMULATED_FLOPS'/g' $simgriddir'/'$PLATFORM_FILE'-simgrid.xml'
echo 'created simgrid platform file'

# create simgrid deployment file
SIMGRID_TASK_MAPPING=$(printf "host%s," "${TASK_MAPPING[@]}")
echo $SIMGRID_TASK_MAPPING | sed 's/,/\n/g' > $simgriddir'/deployment-simgrid.txt'
echo 'create simgrid deployment file'

# simgrid simulation
smpirun -ext smpi_replay $SIMGRID_OPTS -trace --cfg=tracing/filename:$simgriddir'/'$TRACE_NAME-simgrid.trace -hostfile $simgriddir'/deployment-simgrid.txt' -platform $simgriddir'/'$PLATFORM_FILE'-simgrid.xml' -np $NTASKS ../simgrid/SimGrid-3.12/examples/smpi/smpi_replay $SIMGRID_INPUT
echo 'simgrid simulation is done'

# convert the simgrid trace to pjdump
pj_dump --float-precision=9 $simgriddir'/'$TRACE_NAME-simgrid.trace > $simgriddir'/'$TRACE_NAME-simgrid.pjdump
echo 'got simgrid pjdump trace'

###############################################
# plotting

# create directory for storing plotting files
plotdir='plot'
rm -r $plotdir
mkdir $plotdir

# filter dimemas and simgrid pjdump
cat $dimemasdir'/'$TRACE_NAME-dimemas.pjdump | grep ^State | sed "s/rank-//" | cut -d, -f2,4-6,8 > $plotdir'/'$TRACE_NAME-dimemas-filter.pjdump
cat $simgriddir'/'$TRACE_NAME-simgrid.pjdump | grep ^State | sed "s/rank-//" | cut -d, -f2,4-7,8 | sed -n "/^[^,]*,[^,]*,[^,]*,[^,]*, 0/!p" | cut -d, -f1-4,6 > $plotdir'/'$TRACE_NAME-simgrid-filter.pjdump
echo 'pjdumps filtered'

cd $plotdir
Rscript ../getcharts.R $TRACE_NAME-dimemas-filter.pjdump $TRACE_NAME-simgrid-filter.pjdump
cd ..

##############################################
# copy simulator and other relevant files
cp -r dimemas $EXECDIR
cp -r simgrid $EXECDIR
cp -r original $EXECDIR
cp -r plot $EXECDIR





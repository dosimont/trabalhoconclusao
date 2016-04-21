#!/bin/bash

TRACE_NAME='sendrecv6'

# general options
NTASKS=4
BANDWIDTH=1000000 # in bytes/s
LATENCY=1 # in seconds
CORES=4
ORIGINAL_FLOPS=286087000.0 # in flops/s
SIMULATED_FLOPS=286087.0 # in flops/s
TASK_MAPPING=(0 1 0 1)
PLATFORM_FILE='small'


# create temp directory for storing intermediary files (platform descriptions)
tempdir=$(mktemp -d)

# convert the prv trace to the dim format
./../dimemas/dimemas-5.2.12/prv2dim/prv2dim $TRACE_NAME.prv $TRACE_NAME.dim &> /dev/null
echo 'prv trace converted to the dim format'

# create dimemas config file
cp 'platforms/'$PLATFORM_FILE'.cfg' $tempdir'/'$PLATFORM_FILE'-dimemas.cfg'
perl -pi -e 's/\$CORES\$/'$CORES'/g' $tempdir'/'$PLATFORM_FILE'-dimemas.cfg'
DIMEMAS_BANDWIDTH=$(echo 'scale=6; '$BANDWIDTH'/1000000' | bc)
perl -pi -e 's/\$BANDWIDTH\$/0'$DIMEMAS_BANDWIDTH'/g' $tempdir'/'$PLATFORM_FILE'-dimemas.cfg'
DIMEMAS_LATENCY=$(echo 'scale=6; '$LATENCY'/1' | bc)
perl -pi -e 's/\$LATENCY\$/0'$DIMEMAS_LATENCY'/g' $tempdir'/'$PLATFORM_FILE'-dimemas.cfg'
perl -pi -e 's/\$NTASKS\$/'$NTASKS'/g' $tempdir'/'$PLATFORM_FILE'-dimemas.cfg'
DIMEMAS_TASK_MAPPING=$(printf ",%s" "${TASK_MAPPING[@]}")
DIMEMAS_TASK_MAPPING=${DIMEMAS_TASK_MAPPING:1}
perl -pi -e 's/\$MAPPING\$/'$DIMEMAS_TASK_MAPPING'/g' $tempdir'/'$PLATFORM_FILE'-dimemas.cfg'
perl -pi -e 's/\$DIMFILE\$/'$TRACE_NAME'.dim/g' $tempdir'/'$PLATFORM_FILE'-dimemas.cfg'
DIMEMAS_RELATIVE_POWER=$(echo 'scale=6; '$SIMULATED_FLOPS'/'$ORIGINAL_FLOPS | bc)
perl -pi -e 's/\$POWER\$/0'$DIMEMAS_RELATIVE_POWER'/g' $tempdir'/'$PLATFORM_FILE'-dimemas.cfg'
echo 'created dimemas config file'

# dimemas simulation
./../dimemas/dimemas-5.2.12/Simulator/Dimemas -S 0 -p $TRACE_NAME-dimemas.prv $tempdir'/'$PLATFORM_FILE'-dimemas.cfg'
echo 'dimemas simulation is done'

# convert the dimemas trace to pjdump
perl prv2pjdump.pl -i $TRACE_NAME-dimemas > $TRACE_NAME-dimemas.pjdump
echo 'got dimemas pjdump trace'

# convert the prv trace to the tit format
POWER_NS=$(echo 'scale=12; '$ORIGINAL_FLOPS'/1000000000' | bc)
perl prv2tit.pl -i $TRACE_NAME -p 0$POWER_NS > $TRACE_NAME.tit
echo 'prv trace converted to the tit format'

# separate the tit file according to the task number
SIMGRID_INPUT=$tempdir'/'$TRACE_NAME-smpi-replay.txt
touch $SIMGRID_INPUT
i=0
while [ $i -lt $NTASKS ]; do
    grep ^$i $TRACE_NAME.tit > $tempdir'/'task$i.tit;
    echo $tempdir'/'task$i.tit >> $SIMGRID_INPUT
    i=$((i+1))
done

# create simgrid platform description
cp 'platforms/'$PLATFORM_FILE'.xml' $tempdir'/'$PLATFORM_FILE'-simgrid.xml'
perl -pi -e 's/\$CORES\$/'$CORES'/g' $tempdir'/'$PLATFORM_FILE'-simgrid.xml'
perl -pi -e 's/\$BANDWIDTH\$/'$BANDWIDTH'/g' $tempdir'/'$PLATFORM_FILE'-simgrid.xml'
perl -pi -e 's/\$LATENCY\$/'$LATENCY's/g' $tempdir'/'$PLATFORM_FILE'-simgrid.xml'
perl -pi -e 's/\$POWER\$/0'$SIMULATED_FLOPS'/g' $tempdir'/'$PLATFORM_FILE'-simgrid.xml'
echo 'created simgrid platform file'

# create simgrid deployment file
SIMGRID_TASK_MAPPING=$(printf "host%s," "${TASK_MAPPING[@]}")
echo $SIMGRID_TASK_MAPPING | sed 's/,/\n/g' > $tempdir'/deployment-simgrid.txt'
echo 'create simgrid deployment file'

# simgrid simulation
smpirun -ext smpi_replay -map --cfg=tracing/smpi/computing:'yes' --cfg=tracing/precision:9 --cfg=network/model:SMPI --cfg=smpi/bw_factor:'65472:1.0;15424:1.0;9376:1.0;5776:1.0;3484:1.0;1426:1.0;732:1.0;257:1.0;0:1.0' --cfg=smpi/lat_factor:'65472:1.0;15424:1.0;9376:1.0;5776:1.0;3484:1.0;1426:1.0;732:1.0;257:1.0;0:1.0' --cfg=smpi/send_is_detached_thres:2 --cfg=smpi/async_small_thres:0 --cfg=smpi/cpu_threshold:-1 -trace --cfg=tracing/filename:$TRACE_NAME-simgrid.trace -hostfile $tempdir'/deployment-simgrid.txt' -platform $tempdir'/'$PLATFORM_FILE'-simgrid.xml' -np $NTASKS ../simgrid/SimGrid-3.12/examples/smpi/smpi_replay $SIMGRID_INPUT --log=smpi_kernel.thres:warning --cfg=contexts/factory:thread
echo 'simgrid simulation is done'

# convert the simgrid trace to pjdump
pj_dump --float-precision=9 $TRACE_NAME-simgrid.trace > $TRACE_NAME-simgrid.pjdump
echo 'got simgrid pjdump trace'

# clean up
rm $TRACE_NAME.dim
rm $TRACE_NAME-dimemas.row
rm $TRACE_NAME-dimemas.pcf
rm $TRACE_NAME-dimemas.prv
rm $TRACE_NAME.tit
rm $TRACE_NAME-simgrid.trace

# filter dimemas and simgrid pjdump
cat $TRACE_NAME-dimemas.pjdump | grep ^State | sed "s/rank-//" | cut -d, -f2,4-6,8 > $TRACE_NAME-dimemas-filter.pjdump
cat $TRACE_NAME-simgrid.pjdump | grep ^State | sed "s/rank-//" | cut -d, -f2,4-7,8 | sed -n "/^[^,]*,[^,]*,[^,]*,[^,]*, 0/!p" | cut -d, -f1-4,6 > $TRACE_NAME-simgrid-filter.pjdump
echo 'pjdumps filtered'

Rscript getcharts.R $TRACE_NAME-dimemas-filter.pjdump $TRACE_NAME-simgrid-filter.pjdump

# clean up 2
rm $TRACE_NAME-dimemas.pjdump
rm $TRACE_NAME-dimemas-filter.pjdump
rm $TRACE_NAME-simgrid.pjdump
rm $TRACE_NAME-simgrid-filter.pjdump

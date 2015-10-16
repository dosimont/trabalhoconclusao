#!/usr/bin/perl

my $input = q(EXTRAE_Paraver_trace_mpich); # input file name

use strict;
use warnings;
use Data::Dumper;
use Switch;

my %states;
my %events;

# use dictionary to keep track of translated and ignored events
my %translated_events;
my %ignored_events;

my $number_of_tasks;

my @task_states_buffer;
my @task_events_buffer;
my @task_comms_buffer;

my $power_reference = 286.087E-3; # in flop/mus

sub main {
    my($arg);

    while(defined($arg = shift(@ARGV))) {
        for ($arg) {
            if (/^-i$/) { $input = shift(@ARGV); last; }
            print "unrecognized argument '$arg'\n";
        }
    }
    if(!defined($input) || $input eq "") { die "No valid input file provided.\n"; }
    
    parse_pcf($input.".pcf");
    parse_prv($input.".prv");

    print("Translated events:\n");
    print join ", ", keys %translated_events;
    print("\nIgnored events:\n");
    print join ", ", keys %ignored_events;
    print("\n");
}

my %mpi_call_parameters = (
    "send size" => "50100001",
    "recv size" => "50100002",
    "root" => "50100003",
    "communicator" => "50100004",
    );

my @mpi_calls = (
    "MPI_Finalize",
    "MPI_Init",
    "MPI_Send",
    "MPI_Recv",
    "MPI_Isend",
    "MPI_Irecv",
    "MPI_Wait",
    "MPI_Waitall",
    "MPI_Bcast",
    "MPI_Reduce",
    "MPI_Allreduce",
    "MPI_Barrier",
    "MPI_Comm_split",
    "MPI_Comm_dup",
    "MPI_Gather",
    "MPI_AllGather",
    "MPI_Alltoall",
    );

# Missing MPI calls:
# "MPI_Reduce_scatter"
# "MPI_Alltoallv"
# "MPI_Allgatherv"
# "MPI_GatherV"
# "MPI_Comm_size"



# search for a MPI call in the event's parameters
# in all the cases I have seen, the event type and value are the first
# numbers in the event's parameter list, however we are not making this
# assumption. Instead, we look at all parameters and search for the one
# that is encoding the MPI call
sub extract_mpi_call {
    my %event_info = @_;
    
    # search for a MPI call in the event's parameters
    foreach my $key (keys %event_info) {
	if(defined($events{$key})) {
	    if(defined($events{$key}{value}{$event_info{$key}})) {
		my $event_name = $events{$key}{value}{$event_info{$key}};
		if(grep(/^$event_name$/, @mpi_calls)) {
		    $translated_events{$event_name} = 1;
		    return $event_name;
		}
		else {
		    $ignored_events{$event_name} = 1;
		}
	    }
	}
    }

    return "None";
}

sub generate_tit {
    my($task) = @_;

    # keep translating until some MPI call is still missing some parameters
    while (1) {
	if (scalar @{$task_states_buffer[$task - 1]} == 0) { last; }
	my $state_entry = $task_states_buffer[$task - 1][0];

	# if current state is running, generate tit entry, remove state and continue translating
	if ($state_entry->{"state"} eq "Running") {
	    my $comp_size = ($state_entry->{"end_time"} - $state_entry->{"begin_time"}) * $power_reference;
	    my $time = $state_entry->{"begin_time"};
	    print("$task compute $comp_size\n");
	    shift(@{$task_states_buffer[$task - 1]});
	    next;
	}

	# if there are no events in the buffer and more than one state,
	# remove all states but the last one and continue
	if (scalar @{$task_events_buffer[$task - 1]} == 0
	    && scalar @{$task_states_buffer[$task - 1]} > 1) {
	    shift(@{$task_states_buffer[$task - 1]});
	    next;		
	}

	# if there are no events in the buffer, stop
	if (scalar @{$task_events_buffer[$task - 1]} == 0) {
	    last;
	}

	# remove current state if it does not contain any event and continue
	my $event_entry = $task_events_buffer[$task - 1][0];
	if (!($state_entry->{"begin_time"} <= $event_entry->{"time"}
	    && $state_entry->{"end_time"} > $event_entry->{"time"})) {
	    shift(@{$task_states_buffer[$task - 1]});
	    next;
	}

	# if event is a mpi point to point communication
	# check if the p2p communication is on the communications buffer
	my $mpi_call = $event_entry->{"mpi_call"};
	if ($mpi_call eq "MPI_Send" || $mpi_call eq "MPI_Recv"
	    || $mpi_call eq "MPI_Isend" || $mpi_call eq "MPI_Irecv") {
	    my $found_communication = 0;

	    # if communication buffer is empty, stop translating
	    if (! defined $task_comms_buffer[$task - 1]) {
		last;
	    }

	    for (my $j = 0; $j < scalar @{$task_comms_buffer[$task - 1]}; $j++) {
		my $comm_entry = $task_comms_buffer[$task - 1][$j];
		if ($state_entry->{"begin_time"} <= $comm_entry->{"time"}
		      && $state_entry->{"end_time"} >= $comm_entry->{"time"}) {
		    $found_communication = 1;

		    # if it is on the communication buffer
		    # generate the tit entry and remove the state + event + comm entries
		    my $time = $event_entry->{"time"};
		    switch ($mpi_call) {
			case "MPI_Send" {
			    # FORMAT: <rank> send <dst> <comm_size> [<datatype>]
			    my $dst = $comm_entry->{"destiny"};
			    my $comm_size = $comm_entry->{"comm_size"};
			    print("$task send $dst $comm_size\n");
			}
			case "MPI_Recv" {
			    # FORMAT: <rank> recv <src> <comm_size> [<datatype>]
			    my $src = $comm_entry->{"source"};
			    my $comm_size = $comm_entry->{"comm_size"};
			    print("$task recv $src $comm_size\n");
			}
			case "MPI_Isend" {
			    # FORMAT: <rank> Isend <dst> <comm_size> [<datatype>]
			    my $dst = $comm_entry->{"destiny"};
			    my $comm_size = $comm_entry->{"comm_size"};
			    print("$task Isend $dst $comm_size\n");
			}
			case "MPI_Irecv" {
			    # FORMAT: <rank> Irecv <src> <comm_size> [<datatype>]
			    my $src = $comm_entry->{"source"};
			    my $comm_size = $comm_entry->{"comm_size"};
			    print("$task Irecv $src $comm_size\n");
			}
		    }
		    splice(@{$task_comms_buffer[$task - 1]}, $j, 1);
		    shift(@{$task_events_buffer[$task - 1]});
		    shift(@{$task_states_buffer[$task - 1]});
		    last;
		}
	    }

	    # if communication was not found, stop translating
	    if ($found_communication == 0) {
		last;
	    }
	    else {
		next;
	    }
	}
	
	# if mpi call is not a p2p communication
	# generate a tit entry, remove the state + event and continue 
	my $time = $event_entry->{"time"};
	switch ($mpi_call) {
	    case "MPI_Init" {
		# FORMAT: <rank> init [<set_default_double>]
		print("$task init\n");
	    }
	    case "MPI_Finalize" {
		# FORMAT: <rank> finalize
		print("$task finalize\n");
	    }
	    case "MPI_Wait" {
		# FORMAT: <rank> wait
		print("$task wait\n");
	    }
	    case "MPI_Waitall" {
		# FORMAT: <rank> waitAll
		print("$task waitAll\n");
	    }
	    case "MPI_Bcast" {
		# FORMAT: <rank> bcast <comm_size> [<root> [<datatype>]]
		my $comm_size = $event_entry->{"send_size"} || $event_entry->{"recv_size"};
		my $root = $event_entry->{"root"};
		if (defined $root) {
		    print("$task bcast $comm_size $root\n");
		}
		else {
		    print("$task bcast $comm_size\n");
		}
	    }
	    case "MPI_Reduce" {
		# FORMAT: <rank> reduce <comm_size> <comp_size> [<root> [<datatype>]]
		my $comm_size = $event_entry->{"send_size"} || $event_entry->{"recv_size"};
		my $root = $event_entry->{"root"};
		if (defined $root) {
		    print("$task reduce $comm_size <comp_size> $root\n");
		}
		else {
		    print("$task reduce $comm_size <comp_size>\n");
		}
	    }
	    case "MPI_Allreduce" {
		# FORMAT: <rank> allReduce <comm_size> <comp_size> [<datatype>]
		my $comm_size = $event_entry->{"send_size"} || $event_entry->{"recv_size"};
		print("$task allReduce $comm_size <comp_size>\n");
	    }
	    case "MPI_Comm_split" {
		# FORMAT: <rank> comm_split
		print("$task comm_split\n");
	    }
	    case "MPI_Comm_dup" {
		# FORMAT: <rank> comm_dup
		print("$task comm_dup\n");
	    }
	    case "MPI_Gather" {
		# FORMAT: <rank> gather <send_size> <recv_size> <root> [<send_datatype> <recv_datatype>]
		my $send_size = $event_entry->{"send_size"};
		my $recv_size = $event_entry->{"recv_size"};
		my $root = $event_entry->{"root"};
		if (defined $root) {
		    print("$task gather $send_size $recv_size $root\n");
		}
		else {
		    print("$task gather $send_size $recv_size\n");
		}
	    }
	    case "MPI_AllGather" {
		# FORMAT: <rank> allGather <send_size> <recv_size> [<send_datatype> <recv_datatype>]
		my $send_size = $event_entry->{"send_size"};
		my $recv_size = $event_entry->{"recv_size"};
		print("$task allGather $send_size $recv_size\n");
	    }
	    case "MPI_Alltoall" {
		# FORMAT: <rank> allToAll <send_size> <recv_recv> [<send_datatype> <recv_datatype>]
		my $send_size = $event_entry->{"send_size"};
		my $recv_size = $event_entry->{"recv_size"};
		print("$task alltoall $send_size $recv_size\n");
	    }
	}
	shift(@{$task_events_buffer[$task - 1]});
	shift(@{$task_states_buffer[$task - 1]});	
    }
}

sub add_state_entry {
    my($task, %parameters) = @_;

    my $begin_time = $parameters{"begin_time"};
    my $end_time = $parameters{"end_time"};
    my $state = $parameters{"state"};

    my %entry;
    $entry{"begin_time"} = $begin_time;
    $entry{"end_time"} = $end_time;
    $entry{"state"} = $state;

    push @{ $task_states_buffer[$task - 1] }, \%entry;
    generate_tit($task);
}

sub add_event_entry {
    my($task, %parameters) = @_;

    my $time = $parameters{"time"};
    my $mpi_call = $parameters{"mpi_call"};
    my $send_size = $parameters{"send_size"};
    my $recv_size = $parameters{"recv_size"};
    my $root = $parameters{"root"};
    my $communicator = $parameters{"communicator"};

    my %entry;
    $entry{"time"} = $time;
    $entry{"mpi_call"} = $mpi_call;
    $entry{"send_size"} = $send_size;
    $entry{"recv_size"} = $recv_size;
    $entry{"root"} = $root;
    $entry{"communicator"} = $communicator;
    push @{ $task_events_buffer[$task - 1] }, \%entry;

    generate_tit($task);
}

sub add_communication_entry {
    my($task_send, $task_recv, %parameters) = @_;

    my $time_send = $parameters{"time_send"};
    my $time_recv = $parameters{"time_recv"};
    my $comm_size = $parameters{"comm_size"};
    my $source = $parameters{"source"};
    my $destiny = $parameters{"destiny"};

    my %entry_send;
    $entry_send{"time"} = $time_send;
    $entry_send{"comm_size"} = $comm_size;
    $entry_send{"destiny"} = $destiny;
    push @{ $task_comms_buffer[$task_send - 1] }, \%entry_send;
    generate_tit($task_send);

    my %entry_recv;
    $entry_recv{"time"} = $time_recv;
    $entry_recv{"comm_size"} = $comm_size;
    $entry_recv{"source"} = $source;
    push @{ $task_comms_buffer[$task_recv - 1] }, \%entry_recv;
    generate_tit($task_recv);
}


sub parse_prv {
    my($prv) = @_; # get arguments
    open(INPUT, $prv) or die "Cannot open $prv. $!";

    # check if header is valid, we should get something like #Paraver (dd/mm/yy at hh:m):ftime:0:nAppl:applicationList[:applicationList]
    my $line = <INPUT>;
    chomp $line;
    $line =~ /^\#Paraver / or die "Invalid header '$line'\n";
    my $header = $line;
    $header =~ s/^[^:\(]*\([^\)]*\):// or die "Invalid header '$line'\n";
    $header =~ s/(\d+):(\d+)([^\(\d])/$1\_$2$3/g;
    $header =~ s/,\d+$//g;
    my($max_duration, $resource, $number_of_apps, @app_info_list) = split(/:/, $header);
    $max_duration =~ s/_.*$//g;
    $resource =~ /^(.*)\((.*)\)$/ or die "Invalid resource description '$resource'\n";
    my($number_of_nodes, $node_cpu_count) = ($1, $2);
    $number_of_apps == 1 or die "Only one application can be handled at the moment\n";
    my @node_cpu_count = split(/,/, $node_cpu_count);

    # parse app info
    foreach my $app (1..$number_of_apps) {
        $app_info_list[$app - 1] =~ /^(.*)\((.*)\)$/ or die "Invalid application description\n";
	my $task_info;
        ($number_of_tasks, $task_info) = ($1, $2);
        my(@task_info_list) = split(/,/, $task_info);

	@task_events_buffer = (0);
        foreach my $task (1..$number_of_tasks) {
            my($number_of_threads, $node) = split(/_/, $task_info_list[$task - 1]);
	    my @buffer;
	    $task_events_buffer[$task - 1] = \@buffer;
        }
	
    }

    # start reading records
    while(defined($line=<INPUT>)) {
        chomp $line;

        # state records are in the format 1:cpu:appl:task:thread:begin_time:end_time:state_id
        if($line =~ /^1/) {
            my($record, $cpu, $appli, $task, $thread, $begin_time, $end_time, $state_id) = split(/:/, $line);
	    my $state_name = $states{$state_id}{name};

	    my %parameters;
	    $parameters{"begin_time"} = $begin_time;
	    $parameters{"end_time"} = $end_time;
	    $parameters{"state"} = $state_name;
	    add_state_entry($task, %parameters);
	    
        }

	# event records are in the format 2:cpu:appl:task:thread:time:event_type:event_value
	elsif ($line =~ /^2/) {
	    my($record, $cpu, $appli, $task, $thread, $time, %event_list) = split(/:/, $line);
	    my $mpi_call = extract_mpi_call(%event_list);

	    # if event is a MPI call, get the MPI call parameters from the event entry
	    if($mpi_call ne "None") {
		my $send_size = $event_list{$mpi_call_parameters{"send size"}};
		my $recv_size = $event_list{$mpi_call_parameters{"recv size"}};
		my $root = $event_list{$mpi_call_parameters{"root"}};
		my $comm = $event_list{$mpi_call_parameters{"communicator"}};

		my %parameters;
		$parameters{"time"} = $time;
		$parameters{"mpi_call"} = $mpi_call;
		$parameters{"send_size"} = $send_size;
		$parameters{"recv_size"} = $recv_size;
		$parameters{"root"} = $root;
		$parameters{"communicator"} = $comm;
		add_event_entry($task, %parameters);
	    }
        }

	# communication records are in the format 3:cpu_send:ptask_send:task_send:thread_send:logical_time_send:actual_time_send:cpu_recv:ptask_recv:task_recv:thread_recv:logical_time_recv:actual_time_recv:size:tag
	elsif($line =~ /^3/) { 
           my($record, $cpu_send, $ptask_send, $task_send, $thread_send, $ltime_send, $atime_send, $cpu_recv, $ptask_recv, $task_recv, $thread_recv, $ltime_recv, $atime_recv, $size, $tag) = split(/:/, $line);
	   # get mpi call parameters from the communication entry
	   my %parameters;
	   $parameters{"time_send"} = $ltime_send;
	   $parameters{"time_recv"} = $ltime_recv;
	   $parameters{"comm_size"} = $size;
	   $parameters{"source"} = $task_send;
	   $parameters{"destiny"} = $task_recv;
	   add_communication_entry($task_send, $task_recv, %parameters);
        }

	# communicator record are in the format c:app_id:communicator_id:number_of_process:thread_list (e.g., 1:2:3:4:5:6:7:8)
        if($line =~ /^c/) {
            # print STDERR "Skipping communicator definition\n";
        }
    }

    for my $i (0 .. $#task_events_buffer) {
    	# print("task $i:\n");
    	for my $entry ($task_states_buffer[$i]) {
    	    # print Dumper($entry);
    	}
    	for my $entry ($task_events_buffer[$i]) {
    	    # print Dumper($entry);
    	}
    	for my $entry ($task_comms_buffer[$i]) {
    	    # print Dumper($entry);
    	}
    }


    return;
}

sub parse_pcf {
    my($pcf) = shift; # get first argument
    my $line;

    open(INPUT, $pcf) or die "Cannot open $pcf. $!";
    while(defined($line=<INPUT>)) {
        chomp $line; # remove new line
        if($line =~ /^STATES$/) {
            while((defined($line=<INPUT>)) && ($line =~ /^(\d+)\s+(.*)/g)) {
                $states{$1}{name} = $2;
		$states{$1}{used} = 0;
            }
        }

        if($line =~ /^EVENT_TYPE$/) {
	    my $id;
            while($line=<INPUT>) { # read event
                if($line =~ /VALUES/g) {
		    while((defined($line=<INPUT>)) && ($line =~ /^(\d+)\s+(.*)/g)) { # read event values
			$events{$id}{value}{$1} = $2;
		    }
		    last;
		}
                $line =~ /[\d]\s+(\d+)\s+(.*)/g or next;
                $id = $1;
                $events{$id}{type} = $2;
		$events{$id}{used} = 0;
            }
        }
    }

    #print Dumper(\%states);
    #print Dumper(\%events);
}


main();

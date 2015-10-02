#!/usr/bin/perl

my $input = q(EXTRAE_Paraver_trace_mpich); # input file name

use strict;
use Data::Dumper;
use Switch;

my %states;
my %events;
my $nb_task;

my %translated_events;
my %ignored_events;
my %undefined_events;

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
    print("\nUndefined events:\n");
    print join ", ", keys %undefined_events;
    print("\n");
}

my %mpi_call_parameters = (
    "send size" => "50100001",
    "recv size" => "50100002",
    "root" => "50100003",
    "communicator" => "50100004",
    );

my(%pcf_coll_arg) = (
    "send" => "50100001",
    "recv" => "50100002",
    "root" => "50100003",
    "communicator" => "50100003",
    "compute" => "my_reduce_compute_amount",
    );

my(%tit_translate) = (
    "Running" => "compute",
    "Not created" => "", # skip me
    "I/O" => "",         # skip me
    "Synchronization" => "", # skip me
    "MPI_Comm_size" => "",   # skip me
    "MPI_Comm_rank" => "",   # skip me
    "Outside MPI" => "",     # skip me
    "End" => "",             # skip me
    "MPI_Init" => "init",
    "MPI_Bcast" => "bcast",
    "MPI_Allreduce" => "allReduce",
    "MPI_Alltoallv" => "allToAllV",
    "MPI_Alltoall" => "allToAll",
    "MPI_Reduce" => "reduce",
    "MPI_Allgatherv" => "", # allGatherV Uggly hack 
    "MPI_Gather" => "gather",
    "MPI_Gatherv" => "gatherV",
    "MPI_Reduce_scatter" => "reduceScatter",
    "MPI_Finalize" => "finalize",
    "MPI_Barrier" => "barrier",
    );

my @mpi_calls = (
    "MPI_Allreduce",
    "MPI_Barrier",
    "MPI_Bcast",
    "MPI_Gather",
    "MPI_Reduce",
    "MPI_Finalize",
    "MPI_Init",
    "MPI_Comm_size",
    "MPI_Allgatherv",
    "MPI_Alltoall",
    "MPI_Wait",
    "MPI_Waitall",
    "MPI_Isend",
    );
    
# search for a MPI call in the event's parameters
# in all the cases I have seen, the event type and value are the first
# numbers in the event's parameter list, however we are not making this
# assumption. Instead, we look at all parameters and search for the one
# that is encoding the MPI call
# OBS: The events in the trace file can contain much more than MPI calls
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
	else {
	    $undefined_events{$key} = 1;
	}
    }

    return "None";
}

sub get_mpi_parameters {
    my %event_info = @_;

    my $send_size = $event_info{$mpi_call_parameters{"send size"}};
    my $recv_size = $event_info{$mpi_call_parameters{"recv size"}};
    my $root = $event_info{$mpi_call_parameters{"root"}};
    my $comm = $event_info{$mpi_call_parameters{"communicator"}};

    return ($send_size, $recv_size, $root, $comm);
}

sub create_tit_entry {
    my($task, %parameters) = @_;

    #print Dumper(\%parameters);

    my $mpi_call = $parameters{"mpi_call"};
    my $send_size = $parameters{"send_size"};
    my $recv_size = $parameters{"recv_size"};
    my $root = $parameters{"root"};
    my $comm = $parameters{"communicator"};
    my $comm_size = $parameters{"comm_size"};
    my $source = $parameters{"source"};
    my $destiny = $parameters{"destiny"};

    switch ($mpi_call) {
	case "MPI_Send" {
	    # FORMAT: <rank> send <dst> <comm_size> [<datatype>]
	}
	case "MPI_Isend" {
	    # FORMAT: <rank> Isend <dst> <comm_size> [<datatype>]
	    print("$task Isend $destiny $comm_size\n");
	}
	case "MPI_Recv" {
	    # FORMAT: <rank> recv <src> <comm_size> [<datatype>]
	}
	case "MPI_Irecv" {
	    # FORMAT: <rank> Irecv <src> <comm_size> [<datatype>]
	}
	case "MPI_Bcast" {
	    # FORMAT: <rank> bcast <comm_size> [<root> [<datatype>]
	    my $comm_size = $send_size || $recv_size;
	    print("$task bcast $comm_size $root\n");
	}
	case "MPI_Reduce" {
	    # FORMAT: <rank> reduce <comm_size> <comp_size> [<root> [<datatype>]]
	    my $comm_size = $send_size || $recv_size;
	    print("$task reduce $comm_size <comp_size> $root\n");
	}
	case "MPI_AllReduce" {
	    # FORMAT: <rank> allReduce <comm_size> <comp_size> [<datatype>]
	    my $comm_size = $send_size || $recv_size;
	    print("$task allReduce $comm_size <comp_size>\n");
	}
	case "MPI_Reduce_scatter" {
	    # FORMAT: <rank> reduceScatter <recv_sizes†> <comp_size> [<datatype>]
	}
	case "MPI_Gather" {
	    # FORMAT: <rank> gather <send_size> <recv_size> <root> [<send_datatype> <recv_datatype>]
	    print("$task gather $send_size $recv_size $root\n");
	}
	case "MPI_AllGather" {
	    # FORMAT: <rank> allGather <send_size> <recv_size> [<send_datatype> <recv_datatype>]
	}
	case "MPI_Alltoall" {
	    # FORMAT: <rank> allToAll <send_size> <recv_recv> [<send_datatype> <recv_datatype>]
	    print("$task alltoall $send_size $recv_size\n");
	}
	case "MPI_Alltoallv" {
	    # FORMAT: <rank> allToAllV <send_size> <send_sizes†> <recv_size> <recv_sizes†> [<send_datatype> <recv_datatype>]
	}
	case "MPI_GatherV" {
	    # FORMAT: <rank> gatherV <send_size> <recv_sizes†> <root> [<send_datatype> <recv_datatype>]
	}
	case "MPI_Allgatherv" {
	    # FORMAT: <rank> allGatherV <send_size> <recv_sizes> [<send_datatype> <recv_datatype>]
	    print("$task allGatherV $send_size $recv_size\n");
	}
	case "MPI_Barrier" {
	    print("$task barrier\n");
	    # FORMAT: <rank> barrier
	}
	case "MPI_Wait" {
	    # FORMAT: <rank> wait
	    print("$task wait\n");
	}
	case "MPI_Waitall" {
	    # FORMAT: <rank> waitAll
	    print("$task waitAll\n");
	}
	case "MPI_Init" {
	    # FORMAT: <rank> init [<set_default_double>]
	    print("$task init\n");
	}
	case "MPI_Finalize" {
	    # FORMAT: <rank> finalize
	    print("$task finalize\n");
	}
	case "MPI_Comm_size" {
	    # FORMAT: <rank> comm_size <size>
	    print("$task comm_size <size>\n");
	}
	case "MPI_Comm_split" {
	    # FORMAT: <rank> comm_split
	}
	case "MPI_Comm_dup" {
	    # FORMAT: <rank> comm_dup
	}
    }

    return 0,0;
}

sub seila {
    my $sname;
    my $sname_param;
    my %event_list;

    # MPI Other
    if(defined($event_list{50000003})) {
	$sname = $events{50000003}{value}{$event_list{50000003}};
	$sname_param = "";
    }
    elsif(defined($event_list{50000002})) {
	$sname = $events{50000002}{value}{$event_list{50000002}};
	#print "$events{50000002}{type}\n";
	print "$events{50000002}{value}{$event_list{50000002}}\n";
	my $t;
	if($tit_translate{$sname} =~ /V$/) { # Really Uggly hack because of "poor" tracing of V operations
	    if($event_list{$pcf_coll_arg{"send"}}==251 ||
	       $event_list{$pcf_coll_arg{"recv"}}==251 ) {
	    }

	    $event_list{$pcf_coll_arg{"send"}} = 100000;
	    $event_list{$pcf_coll_arg{"recv"}} = 100000;
	    $sname =~ s/v$//i;
	}

	if($tit_translate{$sname} eq "reduce") { # Uggly hack because the amount of computation is not given
	    $event_list{$pcf_coll_arg{"compute"}} = 1;
	}
	if($tit_translate{$sname} eq "gather") { # Uggly hack because the amount of receive does not make sense here
	    $event_list{$pcf_coll_arg{"recv"}} = $event_list{$pcf_coll_arg{"send"}};
	    $event_list{$pcf_coll_arg{"root"}} = 1; # Uggly hack. AAAAARGH
	}
	if($tit_translate{$sname} eq "reduceScatter") { # Uggly hack because of "poor" tracing
	    $event_list{$pcf_coll_arg{"recv"}} = $event_list{$pcf_coll_arg{"send"}}; 
	    my $foo=$event_list{$pcf_coll_arg{"recv"}};
	    $event_list{$pcf_coll_arg{"recv"}}="";
	    for (1..$nb_task) { $event_list{$pcf_coll_arg{"recv"}} .= $foo." "; }
	    $event_list{$pcf_coll_arg{"compute"}} = 1;
	}

	foreach $t ("send","recv", "compute", "root") {
	    if(defined($event_list{$pcf_coll_arg{$t}}) &&
	       $event_list{$pcf_coll_arg{$t}} ne "0") {
		if($t eq "root") { $event_list{$pcf_coll_arg{$t}}--; }
		$sname_param.= "$event_list{$pcf_coll_arg{$t}} ";
	    }
	}
    }

    # this may be application of trace flushing event and hardware counter, user function, ...

    return($sname,$sname_param);
}

sub parse_prv {
    my($prv) = @_; # get arguments
    open(INPUT, $prv) or die "Cannot open $prv. $!";

    # Check if header is valid, we should get something like #Paraver (dd/mm/yy at hh:m):ftime:0:nAppl:applicationList[:applicationList]
    my $line = <INPUT>;
    chomp $line;
    $line =~ /^\#Paraver / or die "Invalid header '$line'\n";
    my $header = $line;
    $header =~ s/^[^:\(]*\([^\)]*\):// or die "Invalid header '$line'\n";
    $header =~ s/(\d+):(\d+)([^\(\d])/$1\_$2$3/g;
    $header =~ s/,\d+$//g;
    my($max_duration, $resource, $nb_app, @appl) = split(/:/, $header);
    $max_duration =~ s/_.*$//g;
    $resource =~ /^(.*)\((.*)\)$/ or die "Invalid resource description '$resource'\n";
    my($nb_nodes, $cpu_list) = ($1, $2);
    $nb_app == 1 or die "Only one application can be handled at the moment\n";
    my @cpu_list = split(/,/, $cpu_list);

    my(%Appl);
    my($nb_task);
    my @current_tasks_parameters;
    foreach my $app (1..$nb_app) {
        my($task_list);
        $appl[$app-1] =~ /^(.*)\((.*)\)$/ or die "Invalid resource description '$resource'\n";
        ($nb_task, $task_list) = ($1, $2);
        my(@task_list) = split(/,/, $task_list);

        my(%mapping);
        my($task);
        foreach $task (1..$nb_task) {
            my($nb_thread, $node_id) = split(/_/, $task_list[$task - 1]);
            if(!defined($mapping{$node_id})) { $mapping{$node_id} = []; }
            push @{$mapping{$node_id}}, [$task, $nb_thread];

	    my %current_parameters;
	    $current_parameters{"state"} = "None";
	    
	    $current_tasks_parameters[$task - 1] = \%current_parameters;
	    print Dumper(\%{$current_tasks_parameters[$task - 1]});
        }
        $Appl{$app}{nb_task}=$nb_task;
        $Appl{$app}{mapping}=\%mapping;
    }

    

    # start reading records
    while(defined($line=<INPUT>)) {
        chomp $line;

        # state records are in the format 1:cpu:appl:task:thread:begin_time:end_time:state_id
        if($line =~ /^1/) {
            my($record, $cpu, $appli, $task, $thread, $begin_time, $end_time, $state_id) = split(/:/, $line);
	    my $state_name = $states{$state_id}{name};

	    # everytime the state changes, create a tit entry for that task
	    my %parameters = %{$current_tasks_parameters[$task - 1]};
	    create_tit_entry($task, %parameters);
	    
	    $current_tasks_parameters[$task - 1]->{"state"} = $state_name;
	    $current_tasks_parameters[$task - 1]->{"mpi_call"} = undef;
	    $current_tasks_parameters[$task - 1]->{"send_size"} = undef;
	    $current_tasks_parameters[$task - 1]->{"recv_size"} = undef;
	    $current_tasks_parameters[$task - 1]->{"root"} = undef;
	    $current_tasks_parameters[$task - 1]->{"communicator"} = undef;
	    $current_tasks_parameters[$task - 1]->{"comm_size"} = undef;
	    $current_tasks_parameters[$task - 1]->{"comp_size"} = undef;
	    $current_tasks_parameters[$task - 1]->{"source"} = undef;
	    $current_tasks_parameters[$task - 1]->{"destiny"} = undef;

	    #print Dumper(\%{$current_tasks_parameters[$task - 1]});
        }

	# event records are in the format 2:cpu:appl:task:thread:time:event_type:event_value
	elsif ($line =~ /^2/) {
	    my($record, $cpu, $appli, $task, $thread, $time, %event_list) = split(/:/, $line);
	    my $mpi_call = extract_mpi_call(%event_list);

	    # if event is a MPI call, get some MPI call parameters from the event entry
	    if($mpi_call ne "None") {
		my($send_size, $recv_size, $root, $comm) = get_mpi_parameters(%event_list);
		$current_tasks_parameters[$task - 1]->{"mpi_call"} = $mpi_call;
		$current_tasks_parameters[$task - 1]->{"send_size"} = $send_size;
		$current_tasks_parameters[$task - 1]->{"recv_size"} = $recv_size;
		$current_tasks_parameters[$task - 1]->{"root"} = $root;
		$current_tasks_parameters[$task - 1]->{"communicator"} = $comm;
	    }
        }

	# communication records are in the format 3:cpu_send:ptask_send:task_send:thread_send:logical_time_send:actual_time_send:cpu_recv:ptask_recv:task_recv:thread_recv:logical_time_recv:actual_time_recv:size:tag
	elsif($line =~ /^3/) { 
           my($record, $cpu_send, $ptask_send, $task_send, $thread_send, $ltime_send, $atime_send, $cpu_recv, $ptask_recv, $task_recv, $thread_recv, $ltime_recv, $atime_recv, $size, $tag) = split(/:/, $line);
	   # get more parameters from the entry
	   $current_tasks_parameters[$task_send - 1]->{"comm_size"} = $size;
	   $current_tasks_parameters[$task_send - 1]->{"source"} = $task_send;
	   $current_tasks_parameters[$task_send - 1]->{"destiny"} = $task_recv;
	   print Dumper(\%{$current_tasks_parameters[$task_send - 1]});
        }

	# communicator record are in the format c:app_id:communicator_id:number_of_process:thread_list (e.g., 1:2:3:4:5:6:7:8)
        if($line =~ /^c/) {
            print STDERR "Skipping communicator definition\n";
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

    print Dumper(\%states);
    print Dumper(\%events);
}


main();

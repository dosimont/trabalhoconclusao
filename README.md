# Thu, Sep 10
I was testing the conversion of the lulesh2.0_p216_n108_t1.chop1 trace and I came across the following problem:

This code snippet opens a file for each node.
```perl
my $nb_proc = 0;
foreach my $node (@{$$resource_name{NODE}}) { 
	my $filename = $output."_$nb_proc.tit";
	open($fh[$nb_proc], "> $filename") or die "Cannot open > $filename: $!";
	nb_proc++;
}
```
While this code snippet assumes the number of opened files is equal to the number of tasks.
```perl
$task = $task - 1;
defined($tit_translate{$sname}) or die "Unknown state '$sname' for tit\n";
if($tit_translate{$sname} ne "") {
	print { $fh[$task] } "$task $tit_translate{$sname} $sname_param\n",
}
```
Currrently, i am assuming that there must be one .tit file for each node, therefore, I modified the last snippet to write on the task's node .tit file.

# Sun, Sep 13

**Some notes:**

Understanding the performance of parallel applications is a concern in the HPC community.
When considering platforms that are not available, it is necessarty to simulate the application. Therefore, it is possible to determine a cost-effective hardware configuration for that particular application.
When considering a platform that is available, simulating is also important since the access to large-scale platforms can be costly.

Two frameworks for simulating MPI applications:
1. On-line simulations
	* The same amount of hardware is required to simulate.
	* Usually uses a simple network model to calculate the communication delays.
	* Can simulate the computational delays, but data-dependent application behavior is lost.
2. Off-line simulations
	* Use a trace of the parallel application.
	* Can be performed on a single computer.
	* Computational delays are scaled based on the performance differential between the original and the simulated platform.
		* If simulator uses time information, target and original platform must be the same.
		* If trace is time independent, the only condition is that the processors of the target platforms must be of the same family as the original platform.
	* Communication delays are computed based on a network simulator.
	* Partially addresses the simulation of data-dependent application. Some data-dependent behavior can be captured in the trace and simulated.

Off-line simulators differ by the simulation models they employ to compute simulated durations of CPU bursts and communication operations.

On a time-independent trace, the CPU bursts or communication operations are logged with its volume (in number of executed instructions or in number of transferred bytes) instead of the time when it begins and ends or its duration.
Therefore, the trace can not be associated with a platform anymore (with the exception of the processor family).
This imply that the MPI application can not modify its execution according to the execution platform (AMPI applications).

**For large numbers of processes and/or numbers of actions, it may be preferable to split the trace so as to obtain one trace file per process.**

**Table 1: Time-independent actions corresponding to supported MPI communication operations.**
MPI actions | Trace entry
--- | ---
CPU burst | `<rank> compute <volume>`
MPI_Send | `<rank> send <dst_rank> <volume>`
MPI_Isend | `<rank> Isend <dst_rank> <volume>`
MPI_Recv | `<rank> recv <src_rank> <volume>`
MPI_Irecv | `<rank> Irecv <src_rank> <volume>`
MPI_Broadcast | `<rank> bcast <volume>`
MPI_Reduce | `<rank> reduce <vcomm> <vcomp>`
MPI_Reduce_scatter | `<rank> reduceScatter <recv_counts> <vcomp>`
MPI_Allreduce | `<rank> allReduce <vcomm> <vcomp>`
MPI_Alltoall | `<rank> allToAll <send_volume> <recv_volume>`
MPI_Alltoallv | `<rank> allToAllv <send_volume> <send_counts> <recv_volume> <recv_counts>`
MPI_Gather | `<rank> gather <send_volume> <recv_volume>`
MPI_Allgatherv | `<rank> allGatherV <send_count> <recv_counts>`
MPI_Barrier | `<rank> barrier`
MPI_Wait | `<rank> wait`
MPI_Waitall | `<rank> waitAll`

Source: references/ref1.pdf

**Questions:**
1. The use of a time-independent trace collected on a platform X can be used to simulate a platform Y under what conditions? Condition example, X and Y must contain the same family of processors or same number of processors. The reference 1 was not so clear about this.

# Tue, Sep 15



CEXES = initfinalize sendrecv1 sendrecv2 sendrecv3 gather gatherv allgather allgatherv bcast reduce allreduce barrier sendrecv4 reducescatter alltoall alltoallv

all: cexam

cexam: $(CEXES)

.c:
	mpicc $(CFLAG) $< -o $@

clean:
	rm -f $(CEXES)

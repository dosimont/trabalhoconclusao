/*
 * sendrecv3.c
 * MPI_Isend, MPI_Irecv and MPI_Wait
 * Processes use nonblocking sends and receives to exchange some messages.
 * A MPI_Wait call is used to synchronize all the processes.
 */

#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>

int main(int argc, char **argv) {
    MPI_Init(&argc, &argv);

    int rank, num_procs;
    MPI_Comm_size(MPI_COMM_WORLD, &num_procs);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    if(num_procs < 2 || num_procs % 2 != 0) {
      MPI_Finalize();
      return 1;
    }

    MPI_Request request;
    request = MPI_REQUEST_NULL;
    if(rank % 2 == 0) {
      int msg = 9999;
      MPI_Isend(&msg, 1, MPI_INT, rank + 1, 1234, MPI_COMM_WORLD, &request);
      printf("process %d sent message to process %d\n", rank, rank + 1);
    }
    else {
      int buffer;
      MPI_Irecv(&buffer, 1, MPI_INT, rank - 1, 1234, MPI_COMM_WORLD, &request);
      printf("process %d received a message from process %d\n", rank, rank - 1);
    }

    MPI_Status status;
    MPI_Wait(&request, &status);

    MPI_Finalize();
}

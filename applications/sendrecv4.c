/*
 * sendrecv4.c
 * MPI_Isend, MPI_Irecv and MPI_Waitall
 * Processes use nonblocking sends and receives to exchange some messages.
 * A MPI_Waitall call is used to synchronize all the processes.
 */

#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>

int main(int argc, char **argv) {
    MPI_Init(&argc, &argv);

    int rank, num_procs;
    MPI_Comm_size(MPI_COMM_WORLD, &num_procs);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    if(num_procs < 4 || num_procs % 2 != 0) {
      MPI_Finalize();
      return 1;
    }

    MPI_Request requests[2];
    requests[0] = MPI_REQUEST_NULL;
    requests[1] = MPI_REQUEST_NULL;
    if(rank % 2 == 0) {
      int msg = 9999;
      MPI_Isend(&msg, 1, MPI_INT, rank + 1, 1234, MPI_COMM_WORLD, &requests[0]);
      MPI_Isend(&msg, 1, MPI_INT, (rank + 3 >= num_procs ? 1 : rank + 3), 1234, MPI_COMM_WORLD, &requests[1]);
    }
    else {
      int buffer;
      MPI_Irecv(&buffer, 1, MPI_INT, rank - 1, 1234, MPI_COMM_WORLD, &requests[0]);
      MPI_Irecv(&buffer, 1, MPI_INT, (rank - 3 < 0 ? num_procs - 2 : rank - 3), 1234, MPI_COMM_WORLD, &requests[1]);
    }

    MPI_Status status[2];
    MPI_Waitall(2, requests, status);

    if(rank % 2 == 0) {
      printf("process %d sent message to process %d and %d\n", rank, rank + 1, (rank + 3 >= num_procs ? 1 : rank + 3));
    }
    else {
      printf("process %d received a message from process %d and %d\n", rank, rank - 1, (rank - 3 < 0 ? num_procs - 2 : rank - 3));
    }

    MPI_Finalize();
}

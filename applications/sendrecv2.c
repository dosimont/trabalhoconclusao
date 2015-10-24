/*
 * sendrecv2.c
 * MPI_Send and MPI_Recv
 * The processes send and receive messages with different sizes.
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

    if(rank % 2 == 0) {
      int *msg = (int *)malloc((rank + 1) * sizeof(int));
      int i;
      for(i = 0; i < rank; i++) {
	msg[i] = i;
      }
      MPI_Send(msg, 1, MPI_INT, rank + 1, 1234, MPI_COMM_WORLD);
      printf("process %d sent message to process %d\n", rank, rank + 1);
    }
    else {
      MPI_Status status;
      int msg_size;
      MPI_Probe(rank - 1, 1234, MPI_COMM_WORLD, &status);
      MPI_Get_count(&status, MPI_INT, &msg_size);
      int *buffer = (int *)malloc(msg_size * sizeof(int));
      MPI_Recv(buffer, msg_size, MPI_INT, rank - 1, 1234, MPI_COMM_WORLD, &status);
      printf("process %d received a message from process %d\n", rank, rank - 1);
    }
    MPI_Finalize();
}

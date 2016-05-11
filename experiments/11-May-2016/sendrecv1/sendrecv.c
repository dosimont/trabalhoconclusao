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

    int *msg = malloc(1000000*sizeof(int));
    if(rank % 2 == 0) {
      MPI_Send(msg, 1000000, MPI_INT, rank + 1, 1234, MPI_COMM_WORLD);
      printf("process %d sent message to process %d\n", rank, rank + 1);
    }
    else {
      MPI_Status status;
      MPI_Recv(msg, 1000000, MPI_INT, rank - 1, 1234, MPI_COMM_WORLD, &status);
      printf("process %d received a message from process %d\n", rank, rank - 1);
    }
    MPI_Finalize();
}

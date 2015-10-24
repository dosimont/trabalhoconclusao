/*
 * bcast.c
 * MPI_Bcast.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>

int main(int argc, char **argv) {
    MPI_Init(&argc, &argv);

    int rank, num_procs;
    MPI_Comm_size(MPI_COMM_WORLD, &num_procs);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    if(num_procs < 4) {
      MPI_Finalize();
      return 1;
    }
 
    int buffer[100];
    int root = 3;
    MPI_Bcast(buffer, 100, MPI_INT, root, MPI_COMM_WORLD);
    printf("process %d received message of size %d from process %d\n", rank, 100, root);

    MPI_Finalize();
}

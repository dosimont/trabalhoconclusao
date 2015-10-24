/*
 * barrier.c
 * MPI_Barrier
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

    srand(rank);
    int rand_num = rand() % 1000000;
    int i;
    int value = 0;
    for (i = 0; i < rand_num; i++) {
      value = i;
    }
    printf("process %d finished his computation\n", rank);
   
    MPI_Barrier(MPI_COMM_WORLD);
    printf("process %d will continue execution\n", rank);

    MPI_Finalize();
}

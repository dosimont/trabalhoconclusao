/*
 * allreduce.c
 * MPI_Allreduce.c
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

    int buffer[10];
    int i;
    for (i = 0; i < 10; i++) {
      buffer[i] = rand() % 10;
    }
    
    int local_sum = 0;
    for (i = 0; i < 10; i++) {
      local_sum += buffer[i];
    }

    printf("local sum of process %d is %d\n", rank, local_sum);

    int global_sum;
    MPI_Allreduce(&local_sum, &global_sum, 1, MPI_INT, MPI_SUM, MPI_COMM_WORLD);
    printf("global sum on process %d is %d\n", rank, global_sum);

    MPI_Finalize();
}

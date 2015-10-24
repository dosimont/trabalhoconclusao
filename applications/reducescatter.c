/*
 * reducescatter.c
 * MPI_Reduce_scatter
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

    int *buffer = (int *)malloc(num_procs * sizeof(int));
    int i;
    printf("process %d:\n", rank);
    for (i = 0; i < num_procs; i++) {
      buffer[i] = rand() % 10;
      printf("%d ", buffer[i]);
    }
    printf("\n");
    
    int local_sum = 0;
    for (i = 0; i < num_procs; i++) {
      local_sum += buffer[i];
    }

    printf("local sum of process %d is %d\n", rank, local_sum);

    int *recv_counts = (int *)malloc(num_procs * sizeof(int));
    for (i = 0; i < num_procs; i++) {
        recv_counts[i] = 1;
    }

    int recv_buffer = 0;
    MPI_Reduce_scatter(buffer, &recv_buffer, recv_counts, MPI_INT, MPI_SUM, MPI_COMM_WORLD);
    
    printf("recv buffer of process %d is %d\n", rank, recv_buffer);
    
    MPI_Finalize();
}

/*
 * alltoall.c
 * MPI_Alltoall
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

    int chunk = 5;
    int *send_buffer = (int *)malloc(num_procs * chunk * sizeof(int));
    int *receive_buffer = (int *)malloc(num_procs * chunk * sizeof(int));
    int i;
    for (i = 0; i < num_procs * chunk; i++) {
        send_buffer[i] = rank;
        receive_buffer[i] = 0;
    }
    MPI_Alltoall(send_buffer, chunk, MPI_INT, receive_buffer, chunk, MPI_INT, MPI_COMM_WORLD);

    printf("process %d:\n", rank);
    for (i = 0; i < num_procs * chunk; i++) {
      printf("%d ", receive_buffer[i]);
    }
    printf("\n");

    MPI_Finalize();
}

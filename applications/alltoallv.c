/*
 * alltoallv.c
 * MPI_Alltoallv
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

    int chunk = 5;
    int *send_buffer = (int *)malloc(num_procs * (rank + 1) * sizeof(int));
    int i;
    for (i = 0; i < num_procs * (rank + 1); i++) {
        send_buffer[i] = rank + 1;
    }

    int *receive_buffer = (int *)malloc(((num_procs * (num_procs + 1))/2) * sizeof(int));
    for (i = 0; i < ((num_procs * (num_procs + 1))/2); i++) {
        receive_buffer[i] = 0;
    }

    int *send_counts = (int *)malloc(num_procs * sizeof(int));
    int *recv_counts = (int *)malloc(num_procs * sizeof(int));
    int *recv_displs = (int *)malloc(num_procs * sizeof(int));
    int *send_displs = (int *)malloc(num_procs * sizeof(int));
    for (i = 0; i < num_procs; i++) {
        send_counts[i] = rank + 1;
        recv_counts[i] = num_procs;
        recv_displs[i] = i == 0 ? 0 : recv_displs[i - 1] + i;
        send_displs[i] = i * (rank + 1);
    }
    MPI_Alltoallv(send_buffer, send_counts, send_displs, MPI_INT, receive_buffer, recv_counts, recv_displs, MPI_INT, MPI_COMM_WORLD);

    printf("process %d result buffer:\n", rank);
    for (i = 0; i < ((num_procs * (num_procs + 1))/2); i++) {
      printf("%d ", receive_buffer[i]);
    }
    printf("\n");

    MPI_Finalize();
}

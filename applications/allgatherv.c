/*
 * allgatherv.c
 * MPI_Allgatherv
 * All processes gather the buffers (of different sizes) from all the other processes and store them in different positions in the receive buffer.
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

    int stride = 1;
    int *displs = (int *)malloc(num_procs * sizeof(int));
    int *rcounts = (int *)malloc(num_procs * sizeof(int)); 
    int i;
    int current_position = 0;
    for (i = 0; i < num_procs; i++) {  
      rcounts[i] = i + 1;
      displs[i] = current_position;
      current_position = current_position + rcounts[i] + stride;
    }

    int *receive_buffer;
    receive_buffer = (int *)malloc((current_position) * sizeof(int));
    for (i = 0; i < current_position; i++) {  
      receive_buffer[i] = -1;
    }

    int *send_buffer;
    send_buffer = (int *)malloc((rank + 1) * sizeof(int));
    for (i = 0; i < rank + 1; i++) {  
      send_buffer[i] = rank;
    }

    MPI_Allgatherv(send_buffer, rank + 1, MPI_INT, receive_buffer, rcounts, displs, MPI_INT, MPI_COMM_WORLD);
    printf("process %d sent message of size %d to all processes\n", rank, rank + 1);

    MPI_Finalize();
}

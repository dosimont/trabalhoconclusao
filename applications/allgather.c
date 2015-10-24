/*
 * allgather.c
 * MPI_Allgather
 * All processes gather the buffers from all the other processes.
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

    int send_buffer[100]; 
    int *receive_buffer;
    receive_buffer = (int *)malloc(num_procs * 100 * sizeof(int)); 
    MPI_Allgather(send_buffer, 100, MPI_INT, receive_buffer, 100, MPI_INT, MPI_COMM_WORLD);
    printf("process %d sent message of size %d to other processes\n", rank, 100);

    MPI_Finalize();
}

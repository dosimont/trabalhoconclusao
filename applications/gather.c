/*
 * gather.c
 * MPI_Gather
 * The root process gathers the buffers from all the other processes.
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
    int root = 3;
    int *receive_buffer;
    if (rank == root) {
      receive_buffer = (int *)malloc(num_procs * 100 * sizeof(int)); 
    }

    MPI_Bcast(send_buffer, 100, MPI_INT, root-1, MPI_COMM_WORLD);
    
    MPI_Gather(send_buffer, 100, MPI_INT, receive_buffer, 100, MPI_INT, root, MPI_COMM_WORLD);
    
    MPI_Bcast(send_buffer, 100, MPI_INT, root+1, MPI_COMM_WORLD);

    MPI_Finalize();
}

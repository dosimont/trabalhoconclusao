/*
 * initfinalize.c
 * MPI_Init and MPI_Finalize
 * Each process call MPI_Init and MPI_Finalize.
 */

#include <stdio.h>
#include <stdlib.h>
#include <mpi.h>

int main(int argc, char **argv) {
    MPI_Init(&argc, &argv);
    MPI_Finalize();
}

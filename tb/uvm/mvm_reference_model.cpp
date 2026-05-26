#include <stdint.h>
#include <stdio.h>

// The extern "C" wrapper is required so SystemVerilog can link to this 
// function without C++ mangling the function name.
extern "C" {

    /**
     * @brief Golden Reference Model for the MVM Accelerator
     * * @param matrix Flat array representing the N x M matrix (INT8)
     * @param vector Flat array representing the 1 x M vector (INT8)
     * @param result Flat array where the computed N-length results will be stored (INT32)
     * @param rows   The number of rows in the matrix
     * @param cols   The number of columns in the matrix
     */
    void mvm_golden_model(
        const int* matrix,
        const int* vector,
        int* result,
        int rows,
        int cols
    ) {
        // Iterate through each row of the matrix
        for (int i = 0; i < rows; i++) {
            int32_t sum = 0;
            
            // Perform the spatial dot product for this row
            for (int j = 0; j < cols; j++) {
                sum += matrix[i * cols + j] * vector[j];
            }
            
            // Apply the Hardware ReLU (Clamp negative values to 0)
            if (sum < 0) {
                sum = 0;
            }
            
            // Store the finalized scalar result
            result[i] = sum;
        }
    }

}
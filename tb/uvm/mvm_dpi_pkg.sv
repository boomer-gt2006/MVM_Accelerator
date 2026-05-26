`timescale 1ns / 1ps

package mvm_dpi_pkg;

    // We declare the exact signature of the C++ function here.
    // 'byte' in SV perfectly matches 'int8_t' in C++.
    // 'int' in SV perfectly matches 'int32_t' in C++.
    
    import "DPI-C" context function void mvm_golden_model(
        input  int matrix[16],
        input  int vector[4],
        output int  result[4],
        input  int  rows,
        input  int  cols
    );

endpackage
`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
import mvm_dpi_pkg::*; 

class mvm_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(mvm_scoreboard)

    uvm_analysis_imp #(axi_full_seq_item, mvm_scoreboard) axi_full_export;

    int test_matrix [16];
    int test_vector [4];
    int expected_results [4];
    int result_index = 0;
    int matrices_passed = 0;

    function new(string name = "mvm_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        axi_full_export = new("axi_full_export", this);
    endfunction

    // The Master Sequence will call this every time it generates new random data
    function void calculate_baseline();
        mvm_golden_model(test_matrix, test_vector, expected_results, 4, 4);
        result_index = 0; // Reset the row counter for the new matrix
    endfunction

    virtual function void write(axi_full_seq_item trans);
        if (trans.is_write) begin
            int hardware_data = trans.data_q.pop_front();

            if (hardware_data != expected_results[result_index]) begin
                `uvm_fatal("SCOREBOARD", $sformatf("[FAIL] Matrix %0d, Row %0d: C++ Expected=%0d, RTL Output=%0d",
                           matrices_passed, result_index, expected_results[result_index], hardware_data))
            end

            result_index++;
            
            if (result_index == 4) begin
                matrices_passed++;
                // Only print a progress update every 100 matrices to save console memory
                if (matrices_passed % 100 == 0) begin
                    `uvm_info("SCOREBOARD", $sformatf("Successfully verified %0d randomized matrices...", matrices_passed), UVM_LOW)
                end
            end
        end
    endfunction
endclass
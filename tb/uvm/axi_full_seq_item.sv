`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_full_seq_item extends uvm_sequence_item;

    rand logic [31:0] addr;
    rand logic [31:0] data_q[$]; // Queue to hold multiple beats of data
    rand bit          is_write;  // 1 = Write to memory, 0 = Read from memory
    rand int          burst_len; // Number of beats in the burst

    `uvm_object_utils_begin(axi_full_seq_item)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(is_write, UVM_ALL_ON)
        `uvm_field_int(burst_len, UVM_ALL_ON)
        // Note: Queues require custom printing, omitting for simplicity here
    `uvm_object_utils_end

    function new(string name = "axi_full_seq_item");
        super.new(name);
    endfunction

endclass
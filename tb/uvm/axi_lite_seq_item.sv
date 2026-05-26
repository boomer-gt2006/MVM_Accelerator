`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_lite_seq_item extends uvm_sequence_item;

    // The rand keyword allows UVM to generate random values for these 
    rand logic [15:0] addr;
    rand logic [31:0] data;
    rand bit          is_write; // 1 = Write, 0 = Read

    // UVM Factory Registration (Mandatory boilerplate)
    `uvm_object_utils_begin(axi_lite_seq_item)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(is_write, UVM_ALL_ON)
    `uvm_object_utils_end

    // Constructor
    function new(string name = "axi_lite_seq_item");
        super.new(name);
    endfunction

endclass
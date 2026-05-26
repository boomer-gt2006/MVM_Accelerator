`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

typedef uvm_sequencer #(axi_full_seq_item) axi_full_sequencer;

class axi_full_agent extends uvm_agent;
    `uvm_component_utils(axi_full_agent)

    axi_full_driver    driver;
    axi_full_sequencer sequencer;
    axi_full_monitor   monitor;

    function new(string name = "axi_full_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = axi_full_monitor::type_id::create("monitor", this);

        if (get_is_active() == UVM_ACTIVE) begin
            driver    = axi_full_driver::type_id::create("driver", this);
            sequencer = axi_full_sequencer::type_id::create("sequencer", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass
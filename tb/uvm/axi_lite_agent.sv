`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

// We use the built-in uvm_sequencer, parameterized for our sequence item
typedef uvm_sequencer #(axi_lite_seq_item) axi_lite_sequencer;

class axi_lite_agent extends uvm_agent;
    `uvm_component_utils(axi_lite_agent)

    // Declare the three sub-components
    axi_lite_driver    driver;
    axi_lite_sequencer sequencer;
    axi_lite_monitor   monitor;

    function new(string name = "axi_lite_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Phase 1: Build the components based on whether the agent is active or passive
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // The Monitor is ALWAYS built
        monitor = axi_lite_monitor::type_id::create("monitor", this);

        // The Driver and Sequencer are only built if the Agent is ACTIVE
        if (get_is_active() == UVM_ACTIVE) begin
            driver    = axi_lite_driver::type_id::create("driver", this);
            sequencer = axi_lite_sequencer::type_id::create("sequencer", this);
        end
    endfunction

    // Phase 2: Connect the Sequencer's export port to the Driver's import port
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass
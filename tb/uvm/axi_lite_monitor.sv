`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_lite_monitor extends uvm_monitor;
    `uvm_component_utils(axi_lite_monitor)

    // Virtual interface to watch the physical pins
    virtual axi4_lite_if vif;

    // Analysis port: The "megaphone" the monitor uses to broadcast seen transactions
    uvm_analysis_port #(axi_lite_seq_item) ap;

    function new(string name = "axi_lite_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4_lite_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON", "Could not get vif from config DB")
        end
    endfunction

    // Phase 2: The infinite observation loop
    virtual task run_phase(uvm_phase phase);
        axi_lite_seq_item trans;

        forever begin
            @(posedge vif.clk);

            // Watch for a successful AXI-Lite Write Handshake
            if (vif.awvalid && vif.awready && vif.wvalid && vif.wready) begin
                trans = axi_lite_seq_item::type_id::create("trans");
                
                trans.is_write = 1;
                trans.addr     = vif.awaddr;
                trans.data     = vif.wdata;

                // Wait for the response channel to complete the transaction
                wait(vif.bvalid && vif.bready);
                
                // Broadcast the captured transaction to the Scoreboard!
                ap.write(trans);
                
                `uvm_info("MON", $sformatf("Captured Write: Addr=0x%0h, Data=0x%0h", trans.addr, trans.data), UVM_HIGH)
            end
        end
    endtask

endclass
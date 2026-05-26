`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_lite_driver extends uvm_driver #(axi_lite_seq_item);
    `uvm_component_utils(axi_lite_driver)

    // The virtual interface connects this software class to the hardware pins
    virtual axi4_lite_if vif;

    function new(string name = "axi_lite_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // Phase 1: Connect the virtual interface from the configuration database
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4_lite_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRV", "Could not get vif from config DB")
        end
    endfunction

    // Phase 2: The infinite hardware execution loop
    virtual task run_phase(uvm_phase phase);
        // Initialize AXI signals to safe defaults
        vif.awvalid <= 0;
        vif.wvalid  <= 0;
        vif.arvalid <= 0;
        vif.bready  <= 0;
        vif.rready  <= 0;

        forever begin
            // Wait for the Sequencer to give us a transaction
            seq_item_port.get_next_item(req);

            // Wait for the next positive clock edge
            @(posedge vif.clk);

            if (req.is_write) begin
                // Execute AXI-Lite Write Handshake
                vif.awaddr  <= req.addr;
                vif.awvalid <= 1;
                vif.wdata   <= req.data;
                vif.wstrb   <= 4'hF;
                vif.wvalid  <= 1;
                vif.bready  <= 1;

                // Wait for hardware to acknowledge the address and data
                wait(vif.awready && vif.wready);
                @(posedge vif.clk);
                vif.awvalid <= 0;
                vif.wvalid  <= 0;

                // Wait for write response
                wait(vif.bvalid);
                @(posedge vif.clk);
                vif.bready <= 0;
                
                `uvm_info("DRV", $sformatf("Wrote Data 0x%0h to Addr 0x%0h", req.data, req.addr), UVM_LOW)
            end 
            else begin
                // (Read handshake logic would go here, omitted for brevity)
                `uvm_info("DRV", "Read operation requested but not fully implemented in basic driver", UVM_LOW)
            end

            // Tell the Sequencer we are done with this transaction
            seq_item_port.item_done();
        end
    endtask

endclass
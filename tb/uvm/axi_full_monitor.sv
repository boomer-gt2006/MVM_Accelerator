`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_full_monitor extends uvm_monitor;
    `uvm_component_utils(axi_full_monitor)

    virtual axi4_full_if vif;
    uvm_analysis_port #(axi_full_seq_item) ap;

    function new(string name = "axi_full_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4_full_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MON_FULL", "Could not get vif from config DB")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        axi_full_seq_item trans;
        logic [31:0] capture_addr;

        forever begin
            @(posedge vif.clk);

            // We primarily care about monitoring WRITES (The scalar results)
            if (vif.awvalid && vif.awready) begin
                capture_addr = vif.awaddr;
            end

            if (vif.wvalid && vif.wready && vif.wlast) begin
                trans = axi_full_seq_item::type_id::create("trans");
                trans.is_write = 1;
                trans.addr     = capture_addr;
                trans.data_q.push_back(vif.wdata); // Capture the scalar result

                wait(vif.bvalid && vif.bready);
                
                ap.write(trans); // Send to Scoreboard
                `uvm_info("MON_FULL", $sformatf("Captured Result Write: Addr=0x%0h, Data=%0d", trans.addr, $signed(vif.wdata)), UVM_HIGH)
            end
        end
    endtask

endclass
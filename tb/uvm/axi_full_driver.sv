`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

class axi_full_driver extends uvm_driver #(axi_full_seq_item);
    `uvm_component_utils(axi_full_driver)

    virtual axi4_full_if vif;
    
    // The Mock DDR Memory (Associative Array)
    int sys_mem [int];

    function new(string name = "axi_full_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4_full_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DRV_FULL", "Could not get vif from config DB")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Pre-load memory with exact same test data from the directed testbench
        sys_mem['h1000/4] = {8'd1, 8'd1, 8'd1, 8'd1};
        sys_mem['h1004/4] = {8'd3, 8'd3, 8'd3, 8'd3};
        sys_mem['h1008/4] = {8'hFB, 8'hFB, 8'hFB, 8'hFB}; // -5 packed
        sys_mem['h100C/4] = {8'd5, 8'd0, 8'd5, 8'd0};

        vif.arready <= 0;
        vif.rvalid  <= 0;
        vif.awready <= 0;
        vif.wready  <= 0;
        vif.bvalid  <= 0;

        // Run Read and Write channels concurrently
        fork
            handle_read_channel();
            handle_write_channel();
        join_none
    endtask

    // --- READ CHANNEL (Memory -> DUT) ---
    task handle_read_channel();
        logic [31:0] active_araddr;
        logic [7:0]  active_arlen;
        int          beats_sent;
        
        forever begin
            // 1. RANDOM BACKPRESSURE: Wait 0 to 5 clock cycles before accepting an Address
            repeat($urandom_range(0, 5)) @(posedge vif.clk);
            vif.arready <= 1;
            
            wait(vif.arvalid && vif.arready);
            @(posedge vif.clk);
            active_araddr = vif.araddr;
            active_arlen  = vif.arlen;
            vif.arready <= 0;
            
            beats_sent = 0;
            while (beats_sent <= active_arlen) begin
                // 2. RANDOM BACKPRESSURE: Wait 0 to 3 clock cycles between data beats!
                // This forces the DMA to hold its state mid-burst.
                repeat($urandom_range(0, 3)) @(posedge vif.clk);
                
                vif.rvalid <= 1;
                vif.rdata  <= sys_mem.exists((active_araddr / 4) + beats_sent) ? 
                              sys_mem[(active_araddr / 4) + beats_sent] : 32'd0;
                vif.rlast  <= (beats_sent == active_arlen);
                vif.rresp  <= 2'b00;

                wait(vif.rready);
                @(posedge vif.clk);
                beats_sent++;
                vif.rvalid <= 0; 
                vif.rlast  <= 0;
            end
        end
    endtask

    // --- WRITE CHANNEL (DUT -> Memory) ---
    task handle_write_channel();
        logic [31:0] active_awaddr;
        forever begin
            // 3. RANDOM BACKPRESSURE: Memory is busy, wait before allowing RTL to write
            repeat($urandom_range(0, 6)) @(posedge vif.clk);
            vif.awready <= 1;
            vif.wready  <= 1;

            wait(vif.awvalid);
            @(posedge vif.clk);
            active_awaddr = vif.awaddr;
            vif.awready <= 0;

            wait(vif.wvalid);
            @(posedge vif.clk);
            sys_mem[active_awaddr / 4] = vif.wdata; 
            vif.wready <= 0;

            wait(vif.wlast);
            
            // 4. RANDOM BACKPRESSURE: Delay sending the write confirmation
            repeat($urandom_range(0, 2)) @(posedge vif.clk);
            vif.bvalid <= 1;
            vif.bresp  <= 2'b00;
            wait(vif.bready);
            @(posedge vif.clk);
            vif.bvalid <= 0;
        end
    endtask

endclass
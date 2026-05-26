`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

// =========================================================
// FORCE UVM COMPILATION
// Pulls all UVM classes directly into this compilation unit
// =========================================================
`include "axi_lite_seq_item.sv"
`include "axi_lite_monitor.sv"
`include "axi_lite_driver.sv"
`include "axi_lite_agent.sv"

`include "axi_full_seq_item.sv"
`include "axi_full_monitor.sv"
`include "axi_full_driver.sv"
`include "axi_full_agent.sv"

`include "mvm_scoreboard.sv"
`include "mvm_env.sv"
`include "mvm_test.sv"
// =========================================================

module tb_uvm_top;

    logic clk;
    logic resetn;

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset Generation
    initial begin
        resetn = 0;
        #100 resetn = 1;
    end

    // Instantiate the Physical Interfaces
    axi4_lite_if lite_if(.clk(clk), .resetn(resetn));
    axi4_full_if full_if(.clk(clk), .resetn(resetn));

    logic interrupt;

    // Instantiate the Hardware (DUT)
    mvm_accelerator_top dut (
        .aclk(clk),
        .aresetn(resetn),
        
        // Connect AXI-Lite wires to the Lite Interface
        .s_axi_awaddr (lite_if.awaddr),
        .s_axi_awvalid(lite_if.awvalid),
        .s_axi_awready(lite_if.awready),
        .s_axi_wdata  (lite_if.wdata),
        .s_axi_wstrb  (lite_if.wstrb),
        .s_axi_wvalid (lite_if.wvalid),
        .s_axi_wready (lite_if.wready),
        .s_axi_bresp  (lite_if.bresp),
        .s_axi_bvalid (lite_if.bvalid),
        .s_axi_bready (lite_if.bready),
        .s_axi_araddr (lite_if.araddr),
        .s_axi_arvalid(lite_if.arvalid),
        .s_axi_arready(lite_if.arready),
        .s_axi_rdata  (lite_if.rdata),
        .s_axi_rresp  (lite_if.rresp),
        .s_axi_rvalid (lite_if.rvalid),
        .s_axi_rready (lite_if.rready),

        // Connect AXI-Full wires to the Full Interface
        .m_axi_awaddr (full_if.awaddr),
        .m_axi_awlen  (full_if.awlen),
        .m_axi_awsize (full_if.awsize),
        .m_axi_awburst(full_if.awburst),
        .m_axi_awvalid(full_if.awvalid),
        .m_axi_awready(full_if.awready),
        .m_axi_wdata  (full_if.wdata),
        .m_axi_wstrb  (full_if.wstrb),
        .m_axi_wlast  (full_if.wlast),
        .m_axi_wvalid (full_if.wvalid),
        .m_axi_wready (full_if.wready),
        .m_axi_bresp  (full_if.bresp),
        .m_axi_bvalid (full_if.bvalid),
        .m_axi_bready (full_if.bready),
        .m_axi_araddr (full_if.araddr),
        .m_axi_arlen  (full_if.arlen),
        .m_axi_arsize (full_if.arsize),
        .m_axi_arburst(full_if.arburst),
        .m_axi_arvalid(full_if.arvalid),
        .m_axi_arready(full_if.arready),
        .m_axi_rdata  (full_if.rdata),
        .m_axi_rresp  (full_if.rresp),
        .m_axi_rlast  (full_if.rlast),
        .m_axi_rvalid (full_if.rvalid),
        .m_axi_rready (full_if.rready),
        
        .interrupt    (interrupt)
    );

    // Initial block to start UVM
    // Initial block to start UVM
    initial begin
        uvm_config_db#(virtual axi4_lite_if)::set(null, "uvm_test_top.env.lite_agent.*", "vif", lite_if);
        uvm_config_db#(virtual axi4_full_if)::set(null, "uvm_test_top.env.full_agent.*", "vif", full_if);
        
        // Launch the massive randomized stress test!
        run_test("mvm_stress_test");
    end

endmodule
`timescale 1ns / 1ps

interface axi4_full_if #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32
)(
    input logic clk,
    input logic resetn
);
    // Write Address Channel
    logic [AXI_ADDR_WIDTH-1:0] awaddr;
    logic [7:0]                awlen;
    logic [2:0]                awsize;
    logic [1:0]                awburst;
    logic                      awvalid;
    logic                      awready;

    // Write Data Channel
    logic [AXI_DATA_WIDTH-1:0] wdata;
    logic [(AXI_DATA_WIDTH/8)-1:0] wstrb;
    logic                      wlast;
    logic                      wvalid;
    logic                      wready;

    // Write Response Channel
    logic [1:0]                bresp;
    logic                      bvalid;
    logic                      bready;

    // Read Address Channel
    logic [AXI_ADDR_WIDTH-1:0] araddr;
    logic [7:0]                arlen;
    logic [2:0]                arsize;
    logic [1:0]                arburst;
    logic                      arvalid;
    logic                      arready;

    // Read Data Channel
    logic [AXI_DATA_WIDTH-1:0] rdata;
    logic [1:0]                rresp;
    logic                      rlast;
    logic                      rvalid;
    logic                      rready;

endinterface
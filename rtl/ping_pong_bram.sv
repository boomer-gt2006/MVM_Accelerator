`timescale 1ns / 1ps

// True Dual-Port Ping-Pong BRAM Subsystem
// Parameterized depth and width. 
// Uses two memory banks (Ping and Pong) to allow continuous data streaming.
module ping_pong_bram #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 10  // 1024 depth to accommodate 4KB per bank
)(
    input  logic clk,
    
    // Bank Select Control (Driven by Central FSM)
    input  logic buf_swap_state,

    // -----------------------------------------
    // Port A: DMA Interface (Write-Focused)
    // -----------------------------------------
    input  logic                  port_a_we,
    input  logic [ADDR_WIDTH-1:0] port_a_addr,
    input  logic [DATA_WIDTH-1:0] port_a_data,

    // -----------------------------------------
    // Port B: Compute Interface (Read-Focused)
    // -----------------------------------------
    input  logic                  port_b_re,
    input  logic [ADDR_WIDTH-1:0] port_b_addr,
    output logic [DATA_WIDTH-1:0] port_b_data
);

    // Ping and Pong memory arrays.
    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] ram_ping [0:(1<<ADDR_WIDTH)-1];
    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] ram_pong [0:(1<<ADDR_WIDTH)-1];

    // Read data registers for BRAM output
    logic [DATA_WIDTH-1:0] rdata_ping;
    logic [DATA_WIDTH-1:0] rdata_pong;

    // ==========================================
    // Ping RAM Bank Control
    // ==========================================
    always_ff @(posedge clk) begin
        if (buf_swap_state == 1'b0) begin
            // buf_swap_state 0: DMA has access to Ping Bank
            if (port_a_we) begin
                ram_ping[port_a_addr] <= port_a_data;
            end
        end else begin
            // buf_swap_state 1: Compute has access to Ping Bank
            if (port_b_re) begin
                rdata_ping <= ram_ping[port_b_addr];
            end
        end
    end

    // ==========================================
    // Pong RAM Bank Control
    // ==========================================
    always_ff @(posedge clk) begin
        if (buf_swap_state == 1'b1) begin
            // buf_swap_state 1: DMA has access to Pong Bank
            if (port_a_we) begin
                ram_pong[port_a_addr] <= port_a_data;
            end
        end else begin
            // buf_swap_state 0: Compute has access to Pong Bank
            if (port_b_re) begin
                rdata_pong <= ram_pong[port_b_addr];
            end
        end
    end

    // ==========================================
    // Output Multiplexing
    // ==========================================
    // The compute datapath automatically receives data from the bank
    // it is currently permitted to access based on `buf_swap_state`.
    assign port_b_data = (buf_swap_state == 1'b1) ? rdata_ping : rdata_pong;

endmodule

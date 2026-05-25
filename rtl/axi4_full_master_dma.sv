`timescale 1ns / 1ps

module axi4_full_master_dma #(
    parameter integer C_M_AXI_DATA_WIDTH = 32,
    parameter integer C_M_AXI_ADDR_WIDTH = 32
)(
    input  logic                          aclk,
    input  logic                          aresetn,

    // Control Interface from Central FSM
    input  logic                          dma_fetch_req,
    input  logic [7:0]                    dma_fetch_len, // 0-based for AXI (up to 255 for 256 beats)
    input  logic [C_M_AXI_ADDR_WIDTH-1:0] dma_target_addr,
    output logic                          dma_fetch_done,
    output logic                          dma_busy,
    output logic                          dma_err,

    // AXI4-Full Read Address Channel (AR)
    output logic [C_M_AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0]                    m_axi_arlen,
    output logic [2:0]                    m_axi_arsize,
    output logic [1:0]                    m_axi_arburst,
    output logic                          m_axi_arvalid,
    input  logic                          m_axi_arready,

    // AXI4-Full Read Data Channel (R)
    input  logic [C_M_AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [1:0]                    m_axi_rresp,
    input  logic                          m_axi_rlast,
    input  logic                          m_axi_rvalid,
    output logic                          m_axi_rready,

    // Write Interface to Ping-Pong BRAM
    output logic                          bram_write_en,
    output logic [9:0]                    bram_write_addr,
    output logic [C_M_AXI_DATA_WIDTH-1:0] bram_write_data
);

    // ==========================================================
    // Local Parameters & Constants
    // ==========================================================
    localparam integer BYTES_PER_BEAT = C_M_AXI_DATA_WIDTH / 8;
    localparam logic [2:0] AXI_SIZE   = $clog2(BYTES_PER_BEAT); // e.g., 32-bit = 4 bytes = 3'b010
    localparam integer AXI_4KB_BOUNDARY = 4096;
    localparam integer MAX_BURST_BEATS  = 256;

    // FSM States
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_CALC_BURST,
        ST_AR_REQ,
        ST_R_DATA,
        ST_DONE
    } state_t;

    state_t state, next_state;

    // ==========================================================
    // Internal Registers
    // ==========================================================
    logic [C_M_AXI_ADDR_WIDTH-1:0] r_current_addr;
    logic [15:0]                   r_beats_remaining;
    logic [7:0]                    r_arlen;            // 0-based AXI length
    logic [15:0]                   r_burst_beat_cnt;   // Beats left in current burst
    logic [9:0]                    r_bram_addr;
    logic                          r_err_flag;

    // ==========================================================
    // Core Logic: 4KB Boundary Calculation
    // ==========================================================
    logic [C_M_AXI_ADDR_WIDTH-1:0] next_boundary;
    logic [C_M_AXI_ADDR_WIDTH-1:0] bytes_to_boundary;
    logic [15:0]                   beats_to_boundary;
    logic [15:0]                   calc_burst_beats;

    always_comb begin
        // Find the next 4KB boundary based on the current address
        next_boundary = (r_current_addr + AXI_4KB_BOUNDARY) & ~(AXI_4KB_BOUNDARY - 1);
        bytes_to_boundary = next_boundary - r_current_addr;
        beats_to_boundary = bytes_to_boundary / BYTES_PER_BEAT;
        
        // Determine burst size without crossing 4KB or exceeding MAX_BURST_BEATS
        if (r_beats_remaining < MAX_BURST_BEATS) begin
            if (r_beats_remaining < beats_to_boundary)
                calc_burst_beats = r_beats_remaining;
            else
                calc_burst_beats = beats_to_boundary;
        end else begin
            if (MAX_BURST_BEATS < beats_to_boundary)
                calc_burst_beats = MAX_BURST_BEATS;
            else
                calc_burst_beats = beats_to_boundary;
        end
    end

    // ==========================================================
    // FSM State Transition
    // ==========================================================
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state <= ST_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (dma_fetch_req)
                    next_state = ST_CALC_BURST;
            end
            ST_CALC_BURST: begin
                next_state = ST_AR_REQ;
            end
            ST_AR_REQ: begin
                if (m_axi_arready)
                    next_state = ST_R_DATA;
            end
            ST_R_DATA: begin
                // Transition on receiving the last beat of the burst
                if (m_axi_rvalid && m_axi_rready && m_axi_rlast) begin
                    if (r_err_flag || m_axi_rresp[1]) // Check for SLVERR/DECERR
                        next_state = ST_DONE;
                    else if (r_beats_remaining == 0)
                        next_state = ST_DONE;
                    else
                        next_state = ST_CALC_BURST; // Request next burst chunk
                end
            end
            ST_DONE: begin
                if (!dma_fetch_req) // handshake return to IDLE
                    next_state = ST_IDLE;
            end
            default: next_state = ST_IDLE;
        endcase
    end

    // ==========================================================
    // FSM Datapath & Register Updates
    // ==========================================================
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            r_current_addr    <= '0;
            r_beats_remaining <= '0;
            r_arlen           <= '0;
            r_burst_beat_cnt  <= '0;
            r_bram_addr       <= '0;
            r_err_flag        <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (dma_fetch_req) begin
                        r_current_addr    <= dma_target_addr;
                        // dma_fetch_len is 0-based number of beats in standard AXI, so +1
                        r_beats_remaining <= {8'b0, dma_fetch_len} + 1;
                        r_bram_addr       <= '0;
                        r_err_flag        <= 1'b0;
                    end
                end
                
                ST_CALC_BURST: begin
                    r_arlen <= calc_burst_beats - 1; // AXI length is beats - 1
                    r_burst_beat_cnt <= calc_burst_beats;
                end
                
                ST_AR_REQ: begin
                    if (m_axi_arready) begin
                        // Decrement total beats remaining once AR is accepted
                        r_beats_remaining <= r_beats_remaining - r_burst_beat_cnt;
                    end
                end
                
                ST_R_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        // Advance logical addresses
                        r_current_addr <= r_current_addr + BYTES_PER_BEAT;
                        r_bram_addr    <= r_bram_addr + 1;
                        
                        // Check for AXI Read Errors (SLVERR or DECERR)
                        if (m_axi_rresp[1])
                            r_err_flag <= 1'b1;
                    end
                end
            endcase
        end
    end

    // ==========================================================
    // Output Assignments
    // ==========================================================
    assign dma_busy       = (state != ST_IDLE);
    assign dma_fetch_done = (state == ST_DONE) && !r_err_flag;
    assign dma_err        = r_err_flag;

    // AXI4 AR Channel Driver
    assign m_axi_arvalid = (state == ST_AR_REQ);
    assign m_axi_araddr  = r_current_addr;
    assign m_axi_arlen   = r_arlen;
    assign m_axi_arsize  = AXI_SIZE;
    assign m_axi_arburst = 2'b01; // INCR burst type

    // AXI4 R Channel Driver
    assign m_axi_rready = (state == ST_R_DATA);

    // BRAM Control Driver
    assign bram_write_en   = m_axi_rvalid && m_axi_rready;
    assign bram_write_addr = r_bram_addr;
    assign bram_write_data = m_axi_rdata;

endmodule

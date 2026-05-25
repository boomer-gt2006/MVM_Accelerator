`timescale 1ns / 1ps

module controller_fsm (
    input  logic        clk,
    input  logic        resetn,

    // ==========================================
    // AXI4-Lite Control & Config Interfaces
    // ==========================================
    input  logic        ctrl_start,
    input  logic [31:0] mat_base_addr,
    input  logic [31:0] vec_base_addr,
    input  logic [31:0] res_base_addr,
    input  logic [15:0] dim_rows,
    input  logic [15:0] dim_cols,
    
    output logic        status_idle,
    output logic        status_done,

    // ==========================================
    // AXI4-Full Master DMA (Read/Fetch Channel)
    // ==========================================
    output logic        dma_fetch_req,
    output logic [7:0]  dma_fetch_len, // 0-based AXI length
    output logic [31:0] dma_target_addr,
    input  logic        dma_fetch_done,

    // ==========================================
    // AXI4-Full Master DMA (Write Channel)
    // ==========================================
    output logic        dma_write_req,
    output logic [31:0] dma_write_addr,
    output logic [31:0] dma_write_data,
    input  logic        dma_write_done,

    // ==========================================
    // Ping-Pong BRAM Control
    // ==========================================
    output logic        buf_swap_state,
    output logic        bram_read_en,
    output logic [9:0]  bram_read_addr,

    // ==========================================
    // SIMD Datapath Control
    // ==========================================
    output logic        dp_clear_acc,
    output logic        dp_valid_in,
    output logic        dp_last_in,
    input  logic [31:0] dp_result,
    input  logic        dp_valid_out
);

    // ==========================================
    // State Machine Encoding
    // ==========================================
    typedef enum logic [2:0] {
        ST_IDLE                     = 3'd0,
        ST_CFG_LOAD                 = 3'd1,
        ST_PREFETCH_PING            = 3'd2,
        ST_COMPUTE_PING_FETCH_PONG  = 3'd3,
        ST_COMPUTE_PONG_FETCH_PING  = 3'd4,
        ST_WRITE_RESULT             = 3'd5
    } state_t;

    state_t state, next_state;

    // ==========================================
    // Internal Registers & Counters
    // ==========================================
    logic [15:0] r_row_count;
    logic [15:0] r_beat_count;
    logic [15:0] r_beats_per_row;
    
    logic [31:0] r_current_mat_addr;
    logic [31:0] r_current_res_addr;
    logic [31:0] r_captured_result;

    // 1-Cycle alignment reqs
    logic pipe_valid_req, pipe_last_req, pipe_clear_req;

    // Robust Synchronization Flags
    logic r_dma_req_sent;
    logic r_write_req_sent;
    logic r_dma_fetch_done_flag;
    logic r_dma_write_done_flag;
    logic r_dp_valid_flag;

    // ==========================================
    // Next State Combinational Logic
    // ==========================================
    always_comb begin
        next_state = state;

        case (state)
            ST_IDLE: 
                if (ctrl_start) next_state = ST_CFG_LOAD;
            
            ST_CFG_LOAD: 
                next_state = ST_PREFETCH_PING;
            
            ST_PREFETCH_PING: 
                if (r_dma_fetch_done_flag) next_state = ST_COMPUTE_PING_FETCH_PONG;
            
            ST_COMPUTE_PING_FETCH_PONG, ST_COMPUTE_PONG_FETCH_PING: 
                if (r_dp_valid_flag) next_state = ST_WRITE_RESULT; 
            
            ST_WRITE_RESULT: begin
                // Exit ONLY when the write finishes AND (prefetch for next row is ready OR this is the last row)
                if (r_dma_write_done_flag && (r_dma_fetch_done_flag || r_row_count == dim_rows - 1)) begin
                    if (r_row_count == dim_rows - 1)
                        next_state = ST_IDLE; // All rows are complete!
                    else if (buf_swap_state == 1'b0)
                        next_state = ST_COMPUTE_PONG_FETCH_PING;
                    else
                        next_state = ST_COMPUTE_PING_FETCH_PONG;
                end
            end
            
            default: next_state = ST_IDLE;
        endcase
    end

    // ==========================================
    // Synchronous FSM Execution & Output Logic
    // ==========================================
    always_ff @(posedge clk) begin
        if (!resetn) begin
            state <= ST_IDLE;
            r_dma_fetch_done_flag <= 1'b0;
            r_dp_valid_flag       <= 1'b0;
            r_dma_write_done_flag <= 1'b0;
            r_dma_req_sent        <= 1'b0;
            r_write_req_sent      <= 1'b0;
            dma_fetch_req         <= 1'b0;
            dma_write_req         <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default pulse clear for requests
            dma_fetch_req  <= 1'b0;
            dma_write_req  <= 1'b0;
            pipe_valid_req <= 1'b0;
            pipe_last_req  <= 1'b0;
            pipe_clear_req <= 1'b0; 

            // Catch Event Pulses independently of state
            if (dma_fetch_done) r_dma_fetch_done_flag <= 1'b1;
            if (dma_write_done) r_dma_write_done_flag <= 1'b1;
            if (dp_valid_out) begin
                r_dp_valid_flag   <= 1'b1;
                r_captured_result <= dp_result; // Safely latch result
            end

            case (state)
                ST_IDLE: begin
                    r_row_count    <= '0;
                    buf_swap_state <= 1'b0; 
                end

                ST_CFG_LOAD: begin
                    r_beats_per_row    <= dim_cols[15:2]; // Divide by 4
                    r_current_mat_addr <= mat_base_addr;
                    r_current_res_addr <= res_base_addr;
                    r_dma_fetch_done_flag <= 1'b0; 
                end

                ST_PREFETCH_PING: begin
                    if (!r_dma_req_sent) begin
                        dma_fetch_req   <= 1'b1;
                        r_dma_req_sent  <= 1'b1; 
                        dma_target_addr <= r_current_mat_addr;
                        dma_fetch_len   <= r_beats_per_row[7:0] - 1;
                        r_current_mat_addr <= r_current_mat_addr + (dim_cols); 
                    end
                    buf_swap_state <= 1'b0; // DMA writes to Ping
                    bram_read_addr <= '0;
                    r_beat_count   <= '0;
                    
                    if (next_state != ST_PREFETCH_PING) begin
                        r_dma_req_sent <= 1'b0;
                        r_dma_fetch_done_flag <= 1'b0; 
                        buf_swap_state <= 1'b1; // Setup Compute to read Ping, DMA to write Pong
                    end
                end

                ST_COMPUTE_PING_FETCH_PONG, ST_COMPUTE_PONG_FETCH_PING: begin
                    // 1. Fetch Next Row (Latency Hiding)
                    if (!r_dma_req_sent && r_row_count < dim_rows - 1) begin
                        dma_fetch_req   <= 1'b1;
                        r_dma_req_sent  <= 1'b1;
                        dma_target_addr <= r_current_mat_addr;
                        dma_fetch_len   <= r_beats_per_row[7:0] - 1;
                        r_current_mat_addr <= r_current_mat_addr + (dim_cols);
                    end

                    // 2. Stream Data to Pipeline
                    if (r_beat_count < r_beats_per_row) begin
                        bram_read_addr <= r_beat_count[9:0];
                        pipe_valid_req <= 1'b1;
                        
                        // Fire clear_acc exactly aligned with the 1st beat of the new row
                        if (r_beat_count == 0) pipe_clear_req <= 1'b1;
                        
                        // Fire last_in on the final beat
                        if (r_beat_count == r_beats_per_row - 1) pipe_last_req <= 1'b1;
                        
                        r_beat_count <= r_beat_count + 1;
                    end
                end

                ST_WRITE_RESULT: begin
                    // Fire Write Request
                    if (!r_write_req_sent) begin
                        dma_write_req    <= 1'b1;
                        r_write_req_sent <= 1'b1;
                        dma_write_addr   <= r_current_res_addr;
                        dma_write_data   <= r_captured_result;
                        r_current_res_addr <= r_current_res_addr + 4;
                    end
                    
                    // Cleanup for next cycle
                    if (next_state != ST_WRITE_RESULT) begin
                        r_dma_fetch_done_flag <= 1'b0; 
                        r_dma_write_done_flag <= 1'b0;
                        r_dp_valid_flag       <= 1'b0;
                        r_dma_req_sent        <= 1'b0;
                        r_write_req_sent      <= 1'b0;
                        r_beat_count          <= '0;
                        r_row_count           <= r_row_count + 1;
                        buf_swap_state        <= ~buf_swap_state; // Toggle Ping-Pong
                    end
                end
            endcase
        end
    end

    // ==========================================
    // 1-Cycle Pipeline Alignment for Datapath 
    // ==========================================
    always_ff @(posedge clk) begin
        if (!resetn) begin
            dp_valid_in  <= 1'b0;
            dp_last_in   <= 1'b0;
            dp_clear_acc <= 1'b0;
        end else begin
            dp_valid_in  <= pipe_valid_req;
            dp_last_in   <= pipe_last_req;
            dp_clear_acc <= pipe_clear_req;
        end
    end

    assign bram_read_en = pipe_valid_req;
    assign status_idle  = (state == ST_IDLE);
    assign status_done  = (state == ST_IDLE && r_row_count > 0);

endmodule
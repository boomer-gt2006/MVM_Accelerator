`timescale 1ns / 1ps

module tb_controller_fsm;

    // ==========================================
    // Signals
    // ==========================================
    logic        clk;
    logic        resetn;

    // AXI4-Lite
    logic        ctrl_start;
    logic [31:0] mat_base_addr;
    logic [31:0] vec_base_addr;
    logic [31:0] res_base_addr;
    logic [15:0] dim_rows;
    logic [15:0] dim_cols;
    logic        status_idle;
    logic        status_done;

    // DMA Fetch
    logic        dma_fetch_req;
    logic [7:0]  dma_fetch_len;
    logic [31:0] dma_target_addr;
    logic        dma_fetch_done;

    // DMA Write
    logic        dma_write_req;
    logic [31:0] dma_write_addr;
    logic [31:0] dma_write_data;
    logic        dma_write_done;

    // BRAM
    logic        buf_swap_state;
    logic        bram_read_en;
    logic [9:0]  bram_read_addr;

    // Datapath
    logic        dp_clear_acc;
    logic        dp_valid_in;
    logic        dp_last_in;
    logic [31:0] dp_result;
    logic        dp_valid_out;

    // ==========================================
    // DUT Instantiation
    // ==========================================
    controller_fsm dut (.*); // SystemVerilog wildcard connect for matching names

    // ==========================================
    // Clock Generation
    // ==========================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; 
    end

    // ==========================================
    // MOCK: DMA Fetch Engine (10-cycle latency)
    // ==========================================
    logic [3:0] fetch_timer;
    logic       fetching;
    always_ff @(posedge clk) begin
        if (!resetn) begin
            fetching       <= 1'b0;
            dma_fetch_done <= 1'b0;
            fetch_timer    <= '0;
        end else begin
            dma_fetch_done <= 1'b0; // Default pulse down
            
            if (dma_fetch_req && !fetching) begin
                fetching    <= 1'b1;
                fetch_timer <= 4'd10; // Simulate 10 cycle memory read delay
                $display("[%0t] [MOCK DMA] Fetch Requested: Addr=0x%h, Len=%0d beats", 
                         $time, dma_target_addr, dma_fetch_len+1);
            end else if (fetching) begin
                if (fetch_timer == 0) begin
                    fetching       <= 1'b0;
                    dma_fetch_done <= 1'b1;
                    $display("[%0t] [MOCK DMA] Fetch Completed", $time);
                end else begin
                    fetch_timer <= fetch_timer - 1;
                end
            end
        end
    end

    // ==========================================
    // MOCK: DMA Write Engine (5-cycle latency)
    // ==========================================
    logic [3:0] write_timer;
    logic       writing;
    always_ff @(posedge clk) begin
        if (!resetn) begin
            writing        <= 1'b0;
            dma_write_done <= 1'b0;
            write_timer    <= '0;
        end else begin
            dma_write_done <= 1'b0;
            
            if (dma_write_req && !writing) begin
                writing     <= 1'b1;
                write_timer <= 4'd5;
                $display("[%0t] [MOCK DMA] Write Requested: Addr=0x%h, Data=0x%h", 
                         $time, dma_write_addr, dma_write_data);
            end else if (writing) begin
                if (write_timer == 0) begin
                    writing        <= 1'b0;
                    dma_write_done <= 1'b1;
                    $display("[%0t] [MOCK DMA] Write Completed", $time);
                end else begin
                    write_timer <= write_timer - 1;
                end
            end
        end
    end

    // ==========================================
    // MOCK: SIMD Datapath Pipeline (4-cycle latency)
    // ==========================================
    logic [3:0] shift_last;
    always_ff @(posedge clk) begin
        if (!resetn) begin
            shift_last   <= '0;
            dp_valid_out <= 1'b0;
            dp_result    <= '0;
        end else begin
            // Shift register delays the 'last_in' signal by exactly 4 cycles
            shift_last   <= {shift_last[2:0], dp_last_in};
            dp_valid_out <= shift_last[3];
            
            // Generate some fake result data based on the row
            if (shift_last[3]) begin
                dp_result <= dp_result + 32'd100; 
                $display("[%0t] [MOCK DP] Datapath Valid Out! Result=0x%h", $time, dp_result + 100);
            end
        end
    end

    // ==========================================
    // Test Sequence
    // ==========================================
    initial begin
        // Init
        resetn        = 1'b0;
        ctrl_start    = 1'b0;
        mat_base_addr = 32'h0000_1000;
        vec_base_addr = 32'h0000_2000;
        res_base_addr = 32'h0000_3000;
        
        // Matrix config: 3 rows, 8 columns
        // Since the bus is 32-bit (4 columns per beat), this requires 2 beats per row!
        dim_rows = 16'd3; 
        dim_cols = 16'd8; 

        #100;
        resetn = 1'b1;
        #20;

        $display("==========================================================");
        $display("[TEST] Initiating MVM Accelerator FSM");
        $display("       Matrix: 3 Rows x 8 Cols");
        $display("       Expected Beats per Row: 2");
        $display("==========================================================");

        // Pulse Start
        @(posedge clk);
        ctrl_start <= 1'b1;
        @(posedge clk);
        ctrl_start <= 1'b0;

        // Wait for the FSM to finish all 3 rows
        wait(status_done == 1'b1);
        @(posedge clk);
        
        $display("==========================================================");
        $display("[GLOBAL PASS] FSM Orchestration Complete. status_done asserted.");
        $display("==========================================================");
        $finish;
    end

    // ==========================================
    // Monitoring State Transitions
    // ==========================================
    // This allows us to watch the FSM walk through its states in the console
    // ==========================================
    // Monitoring State Transitions
    // ==========================================
    always @(state) begin 
        case (state)
            3'd0: $display("[%0t] [FSM] State: ST_IDLE", $time);
            3'd1: $display("[%0t] [FSM] State: ST_CFG_LOAD", $time);
            3'd2: $display("[%0t] [FSM] State: ST_PREFETCH_PING", $time);
            3'd3: $display("[%0t] [FSM] State: ST_COMPUTE_PING_FETCH_PONG (Buffer Swap: %b)", $time, buf_swap_state);
            3'd4: $display("[%0t] [FSM] State: ST_COMPUTE_PONG_FETCH_PING (Buffer Swap: %b)", $time, buf_swap_state);
            3'd5: $display("[%0t] [FSM] State: ST_WRITE_RESULT", $time);
        endcase
    end

    // Map internal state for the monitor
    wire [2:0] state = dut.state;

endmodule
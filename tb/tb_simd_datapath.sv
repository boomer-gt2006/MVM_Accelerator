`timescale 1ns / 1ps

module tb_simd_datapath;

    // ==========================================
    // Signals
    // ==========================================
    logic        clk;
    logic        resetn;
    logic        clear_acc;
    logic        valid_in;
    logic        last_in;
    logic [31:0] matrix_val;
    logic [31:0] vector_val;

    logic signed [31:0] result;
    logic               valid_out;

    // ==========================================
    // DUT Instantiation
    // ==========================================
    simd_datapath dut (
        .clk(clk),
        .resetn(resetn),
        .clear_acc(clear_acc),
        .valid_in(valid_in),
        .last_in(last_in),
        .matrix_val(matrix_val),
        .vector_val(vector_val),
        .result(result),
        .valid_out(valid_out)
    );

    // ==========================================
    // Clock Generation (100 MHz)
    // ==========================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; 
    end

    function logic [31:0] pack_int8(input logic signed [7:0] d3, input logic signed [7:0] d2, 
                                    input logic signed [7:0] d1, input logic signed [7:0] d0);
        return {d3, d2, d1, d0};
    endfunction

    // ==========================================
    // Stimulus & Self-Checking Flow
    // ==========================================
    initial begin
        resetn     = 1'b0;
        clear_acc  = 1'b0;
        valid_in   = 1'b0;
        last_in    = 1'b0;
        matrix_val = '0;
        vector_val = '0;

        #100;
        resetn = 1'b1;
        #20;

        // ----------------------------------------------------
        // TEST 1: Basic 4-lane SIMD MAC (Single Cycle Data)
        // ----------------------------------------------------
        $display("[INFO] TEST 1: Basic 4-lane SIMD MAC execution");
        @(posedge clk);
        valid_in   <= 1'b1;
        clear_acc  <= 1'b1;
        last_in    <= 1'b1; // Single cycle means it is immediately the last beat
        matrix_val <= pack_int8(8'd4, 8'd3, 8'd2, 8'd1);
        vector_val <= pack_int8(8'd2, 8'd2, 8'd2, 8'd2);
        
        @(posedge clk);
        valid_in   <= 1'b0;
        clear_acc  <= 1'b0;
        last_in    <= 1'b0;

        wait(valid_out == 1'b1);
        @(negedge clk); // Safely sample away from the transition edge
        
        if (result === 32'd20) begin
            $display("[PASS] Test 1: SIMD unpacked and calculated correctly. Result = %0d", result);
        end else begin
            $error("[FAIL] Test 1: Expected 20, Got %0d", result);
            $finish;
        end

        // ----------------------------------------------------
        // TEST 2: Multi-cycle Pipelined Accumulation
        // ----------------------------------------------------
        #40;
        $display("[INFO] TEST 2: Continuous Multi-cycle Accumulation");
        
        // Cycle 1 Input
        @(posedge clk);
        valid_in   <= 1'b1;
        clear_acc  <= 1'b1; 
        last_in    <= 1'b0; // NOT the last beat
        matrix_val <= pack_int8(8'd1, 8'd1, 8'd1, 8'd1);
        vector_val <= pack_int8(8'd5, 8'd5, 8'd5, 8'd5); 

        // Cycle 2 Input (Back-to-back)
        @(posedge clk);
        clear_acc  <= 1'b0; 
        last_in    <= 1'b1; // This IS the final beat
        matrix_val <= pack_int8(-8'd2, -8'd2, 8'd5, 8'd5);
        vector_val <= pack_int8(8'd2, 8'd2, 8'd2, 8'd2); 
        
        @(posedge clk);
        valid_in   <= 1'b0;
        last_in    <= 1'b0;

        wait(valid_out == 1'b1);
        @(negedge clk);
        
        // Because of the 'last' flag, valid_out is completely silent during the intermediate sum (20)
        // It will only assert for the final accumulated total (32).
        if (result === 32'd32) begin
            $display("[PASS] Test 2: Temporal accumulation worked across pipeline stages. Result = %0d", result);
        end else begin
            $error("[FAIL] Test 2: Expected 32, Got %0d", result);
            $finish;
        end

        // ----------------------------------------------------
        // TEST 3: Hardware ReLU Clamping
        // ----------------------------------------------------
        #40;
        $display("[INFO] TEST 3: Hardware ReLU Clamping (Negative Accumulator)");
        @(posedge clk);
        valid_in   <= 1'b1;
        clear_acc  <= 1'b1;
        last_in    <= 1'b1; 
        matrix_val <= pack_int8(-8'd10, -8'd10, -8'd10, -8'd10);
        vector_val <= pack_int8(8'd5, 8'd5, 8'd5, 8'd5);
        
        @(posedge clk);
        valid_in   <= 1'b0;
        clear_acc  <= 1'b0;
        last_in    <= 1'b0;

        wait(valid_out == 1'b1);
        @(negedge clk);
        
        if (result === 32'd0) begin
            $display("[PASS] Test 3: ReLU successfully clamped negative value to %0d", result);
        end else begin
            $error("[FAIL] Test 3: ReLU failed. Expected 0, Got %0d", result);
            $finish;
        end

        $display("==========================================================");
        $display("[GLOBAL PASS] All SIMD Datapath self-checks cleared.");
        $display("==========================================================");
        $finish;
    end

endmodule
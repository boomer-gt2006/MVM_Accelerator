`timescale 1ns / 1ps

module tb_scalar_datapath;

    // Clock and Reset
    logic clk;
    logic resetn;

    // Inputs
    logic               clear_acc;
    logic               valid_in;
    logic signed [7:0]  matrix_val;
    logic signed [7:0]  vector_val;

    // Outputs
    logic signed [31:0] result;
    logic               valid_out;

    // Instantiate the Unit Under Test (UUT)
    scalar_datapath uut (
        .clk(clk),
        .resetn(resetn),
        .clear_acc(clear_acc),
        .valid_in(valid_in),
        .matrix_val(matrix_val),
        .vector_val(vector_val),
        .result(result),
        .valid_out(valid_out)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Auto-check variables
    integer errors = 0;
    integer expected_queue[$];

    // Monitor and Check Results
    initial begin
        forever begin
            @(posedge clk);
            if (valid_out) begin
                if (expected_queue.size() > 0) begin
                    automatic integer expected = expected_queue.pop_front();
                    if (result !== expected) begin
                        $display("[FAIL] Time: %0t | Expected: %d, Got: %d", $time, expected, result);
                        errors++;
                    end else begin
                        $display("[PASS] Time: %0t | Got expected: %d", $time, result);
                    end
                end else begin
                    $display("[WARNING] Time: %0t | valid_out high but no expected value in queue. Result: %d", $time, result);
                end
            end
        end
    end

    // Test Stimulus
    initial begin
        // Initialize Inputs
        resetn = 0;
        clear_acc = 0;
        valid_in = 0;
        matrix_val = 0;
        vector_val = 0;

        // Wait for reset deassertion
        #20;
        resetn = 1;
        #10;
        @(posedge clk);

        // --- Test Case 1: Simple Accumulation (Positive) ---
        $display("Starting Test Case 1...");
        // Expected: 2*3 = 6
        expected_queue.push_back(6);
        clear_acc = 1;
        valid_in = 1;
        matrix_val = 8'd2;
        vector_val = 8'd3;
        @(posedge clk);
        
        // Expected: 6 + (4*5) = 26
        expected_queue.push_back(26);
        clear_acc = 0;
        valid_in = 1;
        matrix_val = 8'd4;
        vector_val = 8'd5;
        @(posedge clk);
        
        // Expected: 26 + ((-1)*10) = 16
        expected_queue.push_back(16);
        clear_acc = 0;
        valid_in = 1;
        matrix_val = -8'sd1;
        vector_val = 8'd10;
        @(posedge clk);
        
        valid_in = 0;
        #30;

        // --- Test Case 2: ReLU Activation ---
        $display("Starting Test Case 2...");
        // Expected: -10 * 5 = -50 (ReLU clamps to 0)
        expected_queue.push_back(0);
        clear_acc = 1;
        valid_in = 1;
        matrix_val = -8'sd10;
        vector_val = 8'd5;
        @(posedge clk);
        
        // Expected: -50 + ((-2)*10) = -70 -> ReLU = 0
        expected_queue.push_back(0);
        clear_acc = 0;
        valid_in = 1;
        matrix_val = -8'sd2;
        vector_val = 8'd10;
        @(posedge clk);
        
        valid_in = 0;
        #30;

        // --- Test Case 3: Recovery from Negative Accumulator ---
        $display("Starting Test Case 3...");
        // Previous accumulator is -70. Add 8*10 = 80. Result should be 10.
        expected_queue.push_back(10);
        clear_acc = 0;
        valid_in = 1;
        matrix_val = 8'sd8;
        vector_val = 8'd10;
        @(posedge clk);

        valid_in = 0;
        #30;

        // Final Report
        $display("\nSimulation Finished.");
        if (errors == 0) begin
            $display("========================================");
            $display("   TESTBENCH PASSED (0 ERRORS)");
            $display("   Current File Path: c:\\Users\\gt111\\Desktop\\MVM_Accelerator\\scripts\\build_project.tcl");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("   TESTBENCH FAILED (%0d ERRORS)", errors);
            $display("   Current File Path: c:\\Users\\gt111\\Desktop\\MVM_Accelerator\\scripts\\build_project.tcl");
            $display("========================================");
        end
        
        $finish;
    end

endmodule

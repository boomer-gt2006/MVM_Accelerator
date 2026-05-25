`timescale 1ns / 1ps

module simd_datapath (
    input  logic               clk,
    input  logic               resetn,
    
    // Control Signals
    input  logic               clear_acc, // Clear accumulator (start of new vector dot product)
    input  logic               valid_in,  // Input data is valid
    input  logic               last_in,   // Indicates the final beat of the dot product computation
    
    // Data Inputs (4x INT8 packed into 32 bits)
    input  logic [31:0]        matrix_val,
    input  logic [31:0]        vector_val,
    
    // Output
    output logic signed [31:0] result,
    output logic               valid_out  // Result is valid AND final
);

    // ==========================================
    // Stage 1: Unpack and Parallel Multiply
    // ==========================================
    logic signed [15:0] mult_res [0:3];
    logic               s1_valid;
    logic               s1_clear_acc;
    logic               s1_last;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            for (int i = 0; i < 4; i++) mult_res[i] <= '0;
            s1_valid     <= 1'b0;
            s1_clear_acc <= 1'b0;
            s1_last      <= 1'b0;
        end else begin
            s1_valid     <= valid_in;
            s1_clear_acc <= clear_acc;
            s1_last      <= last_in;
            
            if (valid_in) begin
                mult_res[0] <= $signed(matrix_val[7:0])   * $signed(vector_val[7:0]);
                mult_res[1] <= $signed(matrix_val[15:8])  * $signed(vector_val[15:8]);
                mult_res[2] <= $signed(matrix_val[23:16]) * $signed(vector_val[23:16]);
                mult_res[3] <= $signed(matrix_val[31:24]) * $signed(vector_val[31:24]);
            end
        end
    end

    // ==========================================
    // Stage 2: Logarithmic Adder Tree (Level 1)
    // ==========================================
    logic signed [16:0] sum_l1_01;
    logic signed [16:0] sum_l1_23;
    logic               s2_valid;
    logic               s2_clear_acc;
    logic               s2_last;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            sum_l1_01    <= '0;
            sum_l1_23    <= '0;
            s2_valid     <= 1'b0;
            s2_clear_acc <= 1'b0;
            s2_last      <= 1'b0;
        end else begin
            s2_valid     <= s1_valid;
            s2_clear_acc <= s1_clear_acc;
            s2_last      <= s1_last;
            
            if (s1_valid) begin
                sum_l1_01 <= mult_res[0] + mult_res[1];
                sum_l1_23 <= mult_res[2] + mult_res[3];
            end
        end
    end

    // ==========================================
    // Stage 3: Logarithmic Adder Tree (Level 2)
    // ==========================================
    logic signed [17:0] sum_l2;
    logic               s3_valid;
    logic               s3_clear_acc;
    logic               s3_last;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            sum_l2       <= '0;
            s3_valid     <= 1'b0;
            s3_clear_acc <= 1'b0;
            s3_last      <= 1'b0;
        end else begin
            s3_valid     <= s2_valid;
            s3_clear_acc <= s2_clear_acc;
            s3_last      <= s2_last;
            
            if (s2_valid) begin
                sum_l2 <= sum_l1_01 + sum_l1_23;
            end
        end
    end

    // ==========================================
    // Stage 4: Temporal Accumulator
    // ==========================================
    logic signed [31:0] accumulator;
    logic               acc_valid;
    logic               acc_last;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            accumulator <= '0;
            acc_valid   <= 1'b0;
            acc_last    <= 1'b0;
        end else begin
            acc_valid <= s3_valid;
            acc_last  <= s3_last;
            
            if (s3_valid) begin
                if (s3_clear_acc) begin
                    accumulator <= 32'(sum_l2); 
                end else begin
                    accumulator <= accumulator + 32'(sum_l2);
                end
            end
        end
    end

    // ==========================================
    // Output: Hardware ReLU (Combinational)
    // ==========================================
    assign result = (accumulator[31] == 1'b1) ? 32'd0 : accumulator;
    
    // Output is ONLY valid when the accumulated sum is the final mathematical answer
    assign valid_out = acc_valid & acc_last;

endmodule
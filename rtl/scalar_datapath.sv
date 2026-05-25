`timescale 1ns / 1ps

module scalar_datapath (
    input  logic               clk,
    input  logic               resetn,
    
    // Control Signals
    input  logic               clear_acc, // Clear accumulator (start of new vector dot product)
    input  logic               valid_in,  // Input data is valid
    
    // Data Inputs (INT8)
    input  logic signed [7:0]  matrix_val,
    input  logic signed [7:0]  vector_val,
    
    // Output
    output logic signed [31:0] result,
    output logic               valid_out  // Result is valid
);

    // Stage 1: Multiplication
    logic signed [15:0] mult_res;
    logic               mult_valid;
    logic               clear_acc_q;
    
    always_ff @(posedge clk) begin
        if (!resetn) begin
            mult_res    <= '0;
            mult_valid  <= 1'b0;
            clear_acc_q <= 1'b0;
        end else begin
            mult_valid  <= valid_in;
            clear_acc_q <= clear_acc;
            if (valid_in) begin
                mult_res <= matrix_val * vector_val;
            end
        end
    end
    
    // Stage 2: Accumulation
    logic signed [31:0] accumulator;
    logic               acc_valid;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            accumulator <= '0;
            acc_valid   <= 1'b0;
        end else begin
            acc_valid <= mult_valid;
            
            if (mult_valid) begin
                if (clear_acc_q) begin
                    accumulator <= 32'(mult_res); // Sign extend and replace
                end else begin
                    accumulator <= accumulator + 32'(mult_res); // Accumulate
                end
            end
        end
    end

    // Stage 3: Hardware ReLU (Combinational)
    // Negative numbers are clamped to 0
    assign result = (accumulator[31] == 1'b1) ? 32'd0 : accumulator;
    assign valid_out = acc_valid;

endmodule

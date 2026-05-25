`timescale 1ns / 1ps

module axi4_lite_slave #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 16
)(
    // Global Clock and Reset
    input  logic aclk,
    input  logic aresetn,

    // AXI4-Lite Slave Interface
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                          s_axi_awvalid,
    output logic                          s_axi_awready,
    
    input  logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  logic                          s_axi_wvalid,
    output logic                          s_axi_wready,
    
    output logic [1:0]                    s_axi_bresp,
    output logic                          s_axi_bvalid,
    input  logic                          s_axi_bready,
    
    input  logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                          s_axi_arvalid,
    output logic                          s_axi_arready,
    
    output logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                    s_axi_rresp,
    output logic                          s_axi_rvalid,
    input  logic                          s_axi_rready,

    // Control and Status Register Outputs to FSM/Datapath
    output logic        ctrl_start,
    output logic        ctrl_sw_reset,
    output logic        ctrl_int_en,
    output logic [31:0] mat_base_addr,
    output logic [31:0] vec_base_addr,
    output logic [31:0] res_base_addr,
    output logic [15:0] dim_rows,
    output logic [15:0] dim_cols,

    // Status Register Inputs from FSM/Datapath
    input  logic        status_idle,
    input  logic        status_done,
    input  logic        status_dma_err
);

    // Physical Offsets as per Master Plan
    localparam integer ADDR_CONTROL    = 8'h00;
    localparam integer ADDR_STATUS     = 8'h04;
    localparam integer ADDR_MATRIX     = 8'h08;
    localparam integer ADDR_VECTOR     = 8'h0C;
    localparam integer ADDR_RESULT     = 8'h10;
    localparam integer ADDR_DIMENSIONS = 8'h14;

    // AXI4-Lite Handshake Registers
    logic axi_awready;
    logic axi_wready;
    logic axi_bvalid;
    logic axi_arready;
    logic axi_rvalid;
    logic [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;

    // I/O Connections assignments
    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bresp   = 2'b00; // Always return OKAY
    assign s_axi_bvalid  = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rdata   = axi_rdata;
    assign s_axi_rresp   = 2'b00; // Always return OKAY
    assign s_axi_rvalid  = axi_rvalid;

    // Internal Registers
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg_control;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg_matrix;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg_vector;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg_result;
    logic [C_S_AXI_DATA_WIDTH-1:0] slv_reg_dimensions;

    // Output assignments
    assign ctrl_start    = slv_reg_control[0];
    assign ctrl_sw_reset = slv_reg_control[1];
    assign ctrl_int_en   = slv_reg_control[2];
    assign mat_base_addr = slv_reg_matrix;
    assign vec_base_addr = slv_reg_vector;
    assign res_base_addr = slv_reg_result;
    assign dim_rows      = slv_reg_dimensions[15:0];
    assign dim_cols      = slv_reg_dimensions[31:16];

    logic aw_en;

    // Write Address and Data Capture
    always_ff @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            aw_en       <= 1'b1;
        end else begin
            if (~axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                axi_awready <= 1'b1;
                aw_en       <= 1'b0;
            end else if (s_axi_bready && axi_bvalid) begin
                aw_en       <= 1'b1;
                axi_awready <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end

            if (~axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end

    // Write Response Handshake
    always_ff @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            axi_bvalid <= 1'b0;
        end else begin
            if (axi_awready && s_axi_awvalid && ~axi_bvalid && axi_wready && s_axi_wvalid) begin
                axi_bvalid <= 1'b1;
            end else if (s_axi_bready && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // Register Write Logic
    logic slv_reg_wren;
    assign slv_reg_wren = axi_wready && s_axi_wvalid && axi_awready && s_axi_awvalid;

    always_ff @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            slv_reg_control    <= '0;
            slv_reg_matrix     <= '0;
            slv_reg_vector     <= '0;
            slv_reg_result     <= '0;
            slv_reg_dimensions <= '0;
        end else begin
            // Auto-clear the start pulse
            if (slv_reg_control[0]) begin
                slv_reg_control[0] <= 1'b0;
            end
            
            if (slv_reg_wren) begin
                case (s_axi_awaddr[7:0])
                    ADDR_CONTROL: begin
                        for (int byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index++)
                            if (s_axi_wstrb[byte_index])
                                slv_reg_control[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                    end
                    ADDR_MATRIX: begin
                        for (int byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index++)
                            if (s_axi_wstrb[byte_index])
                                slv_reg_matrix[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                    end
                    ADDR_VECTOR: begin
                        for (int byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index++)
                            if (s_axi_wstrb[byte_index])
                                slv_reg_vector[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                    end
                    ADDR_RESULT: begin
                        for (int byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index++)
                            if (s_axi_wstrb[byte_index])
                                slv_reg_result[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                    end
                    ADDR_DIMENSIONS: begin
                        for (int byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index++)
                            if (s_axi_wstrb[byte_index])
                                slv_reg_dimensions[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
                    end
                    default: ;
                endcase
            end
        end
    end

    // Read Address and Data Handshake
    always_ff @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= '0;
        end else begin
            if (~axi_arready && s_axi_arvalid) begin
                axi_arready <= 1'b1;
            end else begin
                axi_arready <= 1'b0;
            end

            if (axi_arready && s_axi_arvalid && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                // Decode read address
                case (s_axi_araddr[7:0])
                    ADDR_CONTROL:    axi_rdata <= slv_reg_control;
                    ADDR_STATUS:     axi_rdata <= {29'b0, status_dma_err, status_done, status_idle};
                    ADDR_MATRIX:     axi_rdata <= slv_reg_matrix;
                    ADDR_VECTOR:     axi_rdata <= slv_reg_vector;
                    ADDR_RESULT:     axi_rdata <= slv_reg_result;
                    ADDR_DIMENSIONS: axi_rdata <= slv_reg_dimensions;
                    default:         axi_rdata <= '0;
                endcase
            end else if (s_axi_rready && axi_rvalid) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

endmodule

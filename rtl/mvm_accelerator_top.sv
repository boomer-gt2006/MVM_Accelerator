`timescale 1ns / 1ps

module mvm_accelerator_top #(
    // AXI4-Lite Slave Parameters (Control Interface)
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 16,

    // AXI4-Full Master Parameters (DMA Interface)
    parameter integer C_M_AXI_DATA_WIDTH = 32,
    parameter integer C_M_AXI_ADDR_WIDTH = 32
)(
    // Global Clock and Reset
    input  logic aclk,
    input  logic aresetn,

    // ==========================================================
    // AXI4-Lite Slave Interface (Control & Status)
    // ==========================================================
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

    // ==========================================================
    // AXI4-Full Master Interface (DMA Engine)
    // ==========================================================
    output logic [C_M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [7:0]                    m_axi_awlen,
    output logic [2:0]                    m_axi_awsize,
    output logic [1:0]                    m_axi_awburst,
    output logic                          m_axi_awvalid,
    input  logic                          m_axi_awready,
    output logic [C_M_AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output logic [(C_M_AXI_DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output logic                          m_axi_wlast,
    output logic                          m_axi_wvalid,
    input  logic                          m_axi_wready,
    input  logic [1:0]                    m_axi_bresp,
    input  logic                          m_axi_bvalid,
    output logic                          m_axi_bready,
    output logic [C_M_AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0]                    m_axi_arlen,
    output logic [2:0]                    m_axi_arsize,
    output logic [1:0]                    m_axi_arburst,
    output logic                          m_axi_arvalid,
    input  logic                          m_axi_arready,
    input  logic [C_M_AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [1:0]                    m_axi_rresp,
    input  logic                          m_axi_rlast,
    input  logic                          m_axi_rvalid,
    output logic                          m_axi_rready,
    
    // Interrupt
    output logic                          interrupt
);

    // ==========================================================
    // Internal Interconnect Signals
    // ==========================================================
    // AXI-Lite to FSM
    logic        ctrl_start;
    logic        ctrl_sw_reset;
    logic        ctrl_int_en;
    logic [31:0] mat_base_addr;
    logic [31:0] vec_base_addr;
    logic [31:0] res_base_addr;
    logic [15:0] dim_rows;
    logic [15:0] dim_cols;
    logic        status_idle;
    logic        status_done;
    logic        status_dma_err;

    // FSM to DMA Fetch
    logic        dma_fetch_req;
    logic [7:0]  dma_fetch_len;
    logic [31:0] dma_target_addr;
    logic        dma_fetch_done;
    logic        dma_busy;

    // FSM to DMA Write
    logic        dma_write_req;
    logic [31:0] dma_write_addr;
    logic [31:0] dma_write_data;
    logic        dma_write_done;

    // FSM & DMA to BRAM
    logic        buf_swap_state;
    logic        bram_write_en;
    logic [9:0]  bram_write_addr;
    logic [31:0] bram_write_data;
    logic        bram_read_en;
    logic [9:0]  bram_read_addr;
    logic [31:0] bram_read_data;

    // FSM to Datapath
    logic        dp_clear_acc;
    logic        dp_valid_in;
    logic        dp_last_in;
    logic [31:0] dp_result;
    logic        dp_valid_out;

    // System Reset routing
    logic sys_rstn;
    assign sys_rstn = aresetn & ~ctrl_sw_reset;
    assign interrupt = status_done & ctrl_int_en;

    // ==========================================================
    // 1. AXI4-Lite Slave (Control Registers)
    // ==========================================================
    axi4_lite_slave #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) axi4_lite_slave_inst (
        .aclk           (aclk),
        .aresetn        (sys_rstn),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        
        .ctrl_start     (ctrl_start),
        .ctrl_sw_reset  (ctrl_sw_reset),
        .ctrl_int_en    (ctrl_int_en),
        .mat_base_addr  (mat_base_addr),
        .vec_base_addr  (vec_base_addr),
        .res_base_addr  (res_base_addr),
        .dim_rows       (dim_rows),
        .dim_cols       (dim_cols),
        .status_idle    (status_idle),
        .status_done    (status_done),
        .status_dma_err (status_dma_err)
    );

    // ==========================================================
    // 2. Central Controller FSM
    // ==========================================================
    controller_fsm controller_fsm_inst (
        .clk            (aclk),
        .resetn         (sys_rstn),
        .ctrl_start     (ctrl_start),
        .mat_base_addr  (mat_base_addr),
        .vec_base_addr  (vec_base_addr),
        .res_base_addr  (res_base_addr),
        .dim_rows       (dim_rows),
        .dim_cols       (dim_cols),
        .status_idle    (status_idle),
        .status_done    (status_done),
        .dma_fetch_req  (dma_fetch_req),
        .dma_fetch_len  (dma_fetch_len),
        .dma_target_addr(dma_target_addr),
        .dma_fetch_done (dma_fetch_done),
        .dma_write_req  (dma_write_req),
        .dma_write_addr (dma_write_addr),
        .dma_write_data (dma_write_data),
        .dma_write_done (dma_write_done),
        .buf_swap_state (buf_swap_state),
        .bram_read_en   (bram_read_en),
        .bram_read_addr (bram_read_addr),
        .dp_clear_acc   (dp_clear_acc),
        .dp_valid_in    (dp_valid_in),
        .dp_last_in     (dp_last_in),
        .dp_result      (dp_result),
        .dp_valid_out   (dp_valid_out)
    );

    // ==========================================================
    // 3. AXI4-Full Master DMA (Read Channel Engine)
    // ==========================================================
    axi4_full_master_dma #(
        .C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
        .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH)
    ) dma_master_inst (
        .aclk           (aclk),
        .aresetn        (sys_rstn),
        .dma_fetch_req  (dma_fetch_req),
        .dma_fetch_len  (dma_fetch_len),
        .dma_target_addr(dma_target_addr),
        .dma_fetch_done (dma_fetch_done),
        .dma_busy       (dma_busy),
        .dma_err        (status_dma_err),
        
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready),
        
        .bram_write_en  (bram_write_en),
        .bram_write_addr(bram_write_addr),
        .bram_write_data(bram_write_data)
    );

    // ==========================================================
    // 4. AXI4-Full Master DMA (Write Channel Bridge)
    // ==========================================================
    typedef enum logic [1:0] { W_IDLE, W_ADDR, W_DATA, W_RESP } write_state_t;
    write_state_t w_state;

    always_ff @(posedge aclk) begin
        if (!sys_rstn) begin
            w_state        <= W_IDLE;
            m_axi_awvalid  <= 1'b0;
            m_axi_wvalid   <= 1'b0;
            m_axi_bready   <= 1'b0;
            dma_write_done <= 1'b0;
        end else begin
            dma_write_done <= 1'b0; 
            case (w_state)
                W_IDLE: begin
                    if (dma_write_req) begin
                        m_axi_awvalid <= 1'b1;
                        m_axi_awaddr  <= dma_write_addr;
                        w_state       <= W_ADDR;
                    end
                end
                W_ADDR: begin
                    if (m_axi_awready && m_axi_awvalid) begin
                        m_axi_awvalid <= 1'b0;
                        m_axi_wvalid  <= 1'b1;
                        m_axi_wdata   <= dma_write_data;
                        w_state       <= W_DATA;
                    end
                end
                W_DATA: begin
                    if (m_axi_wready && m_axi_wvalid) begin
                        m_axi_wvalid <= 1'b0;
                        m_axi_bready <= 1'b1;
                        w_state      <= W_RESP;
                    end
                end
                W_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready   <= 1'b0;
                        dma_write_done <= 1'b1;
                        w_state        <= W_IDLE;
                    end
                end
            endcase
        end
    end

    // Static Write Channel AXI Assignments
    assign m_axi_awlen   = 8'd0;       // 1 beat burst for single scalar result
    assign m_axi_awsize  = 3'b010;     // 4 bytes per beat
    assign m_axi_awburst = 2'b01;      // INCR burst type
    assign m_axi_wstrb   = 4'hF;       // All bytes valid
    assign m_axi_wlast   = 1'b1;       // Single beat is always the last beat

    // ==========================================================
    // 5. Ping-Pong BRAM
    // ==========================================================
    ping_pong_bram #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(10)
    ) bram_inst (
        .clk            (aclk),
        .buf_swap_state (buf_swap_state),
        .port_a_we      (bram_write_en),
        .port_a_addr    (bram_write_addr),
        .port_a_data    (bram_write_data),
        .port_b_re      (bram_read_en),
        .port_b_addr    (bram_read_addr),
        .port_b_data    (bram_read_data)
    );

    // ==========================================================
    // 6. SIMD Datapath
    // ==========================================================
    // Note: The host packs 4 INT8 vector values into the AXI-Lite 
    // vector base register. We map this directly into the datapath.
    simd_datapath simd_dp_inst (
        .clk            (aclk),
        .resetn         (sys_rstn),
        .clear_acc      (dp_clear_acc),
        .valid_in       (dp_valid_in),
        .last_in        (dp_last_in),
        .matrix_val     (bram_read_data),
        .vector_val     (vec_base_addr), 
        .result         (dp_result),
        .valid_out      (dp_valid_out)
    );

endmodule
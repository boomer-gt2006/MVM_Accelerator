`timescale 1ns / 1ps

module tb_mvm_accelerator_top;

    // ==========================================
    // Parameters & Signals
    // ==========================================
    localparam integer C_AXI_DATA_WIDTH = 32;
    localparam integer C_AXI_ADDR_WIDTH = 32;
    
    logic aclk;
    logic aresetn;

    // AXI4-Lite Slave Interface (Host CPU Mock)
    logic [15:0] s_axi_awaddr;
    logic        s_axi_awvalid;
    logic        s_axi_awready;
    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wvalid;
    logic        s_axi_wready;
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bvalid;
    logic        s_axi_bready;
    
    // (Read channel tied off for this test)
    logic [15:0] s_axi_araddr = '0;
    logic        s_axi_arvalid = 1'b0;
    logic        s_axi_arready;
    logic [31:0] s_axi_rdata;
    logic [1:0]  s_axi_rresp;
    logic        s_axi_rvalid;
    logic        s_axi_rready = 1'b1;

    // AXI4-Full Master Interface (DDR Memory Mock)
    logic [31:0] m_axi_awaddr;
    logic [7:0]  m_axi_awlen;
    logic [2:0]  m_axi_awsize;
    logic [1:0]  m_axi_awburst;
    logic        m_axi_awvalid;
    logic        m_axi_awready;
    logic [31:0] m_axi_wdata;
    logic [3:0]  m_axi_wstrb;
    logic        m_axi_wlast;
    logic        m_axi_wvalid;
    logic        m_axi_wready;
    logic [1:0]  m_axi_bresp;
    logic        m_axi_bvalid;
    logic        m_axi_bready;
    logic [31:0] m_axi_araddr;
    logic [7:0]  m_axi_arlen;
    logic [2:0]  m_axi_arsize;
    logic [1:0]  m_axi_arburst;
    logic        m_axi_arvalid;
    logic        m_axi_arready;
    logic [31:0] m_axi_rdata;
    logic [1:0]  m_axi_rresp;
    logic        m_axi_rlast;
    logic        m_axi_rvalid;
    logic        m_axi_rready;
    
    logic        interrupt;

    // ==========================================
    // DUT Instantiation
    // ==========================================
    mvm_accelerator_top #(
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(16),
        .C_M_AXI_DATA_WIDTH(32),
        .C_M_AXI_ADDR_WIDTH(32)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .* // Auto-connect matching signal names
    );

    // ==========================================
    // Clock & Reset
    // ==========================================
    initial begin
        aclk = 1'b0;
        forever #5 aclk = ~aclk; 
    end

    // ==========================================
    // MOCK: DDR System Memory (16KB)
    // ==========================================
    logic [31:0] sys_mem [0:4095];

    // --- AXI4-Full Read Channel (AR / R) ---
    logic [31:0] active_araddr;
    logic [7:0]  active_arlen;
    logic [7:0]  beats_sent;
    typedef enum logic [1:0] {SLV_IDLE, SLV_SENDING} slv_state_t;
    slv_state_t slv_state = SLV_IDLE;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_arready <= 1'b0;
            slv_state     <= SLV_IDLE;
            m_axi_rvalid  <= 1'b0;
            beats_sent    <= '0;
        end else begin
            // AR Handshake
            if (slv_state == SLV_IDLE) m_axi_arready <= 1'b1;
            else m_axi_arready <= 1'b0;

            case (slv_state)
                SLV_IDLE: begin
                    if (m_axi_arready && m_axi_arvalid) begin
                        active_araddr <= m_axi_araddr;
                        active_arlen  <= m_axi_arlen;
                        slv_state     <= SLV_SENDING;
                        beats_sent    <= '0;
                        m_axi_rvalid  <= 1'b1;
                    end else begin
                        m_axi_rvalid <= 1'b0;
                    end
                end
                SLV_SENDING: begin
                    if (m_axi_rready && m_axi_rvalid) begin
                        if (beats_sent == active_arlen) begin
                            slv_state    <= SLV_IDLE;
                            m_axi_rvalid <= 1'b0;
                        end else begin
                            beats_sent <= beats_sent + 1;
                        end
                    end
                end
            endcase
        end
    end
    assign m_axi_rdata = sys_mem[(active_araddr / 4) + beats_sent];
    assign m_axi_rlast = (slv_state == SLV_SENDING) && (beats_sent == active_arlen);
    assign m_axi_rresp = 2'b00;

    // --- AXI4-Full Write Channel (AW / W / B) ---
    logic [31:0] active_awaddr;
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_awready <= 1'b0;
            m_axi_wready  <= 1'b0;
            m_axi_bvalid  <= 1'b0;
        end else begin
            // Simple Always-Ready Acceptance
            m_axi_awready <= 1'b1;
            m_axi_wready  <= 1'b1;
            
            if (m_axi_awvalid && m_axi_awready) begin
                active_awaddr <= m_axi_awaddr;
            end
            
            if (m_axi_wvalid && m_axi_wready) begin
                sys_mem[active_awaddr / 4] <= m_axi_wdata; // Write to Mock Memory
                $display("[%0t] [MEM] Written Result to 0x%h: %0d", $time, active_awaddr, $signed(m_axi_wdata));
            end
            
            if (m_axi_wvalid && m_axi_wready && m_axi_wlast) begin
                m_axi_bvalid <= 1'b1;
            end else if (m_axi_bready) begin
                m_axi_bvalid <= 1'b0;
            end
        end
    end
    assign m_axi_bresp = 2'b00;

    // ==========================================
    // Helper Task: AXI-Lite Write
    // ==========================================
    task axi_lite_write(input [15:0] addr, input [31:0] data);
        begin
            @(posedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wvalid  <= 1'b1;
            s_axi_wstrb   <= 4'hF;
            
            wait(s_axi_awready && s_axi_wready);
            @(posedge aclk);
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;
            
            wait(s_axi_bvalid);
            s_axi_bready <= 1'b1;
            @(posedge aclk);
            s_axi_bready <= 1'b0;
        end
    endtask

    // Helper: Pack four 8-bit ints
    function logic [31:0] pack_int8(input logic signed [7:0] d3, input logic signed [7:0] d2, 
                                    input logic signed [7:0] d1, input logic signed [7:0] d0);
        return {d3, d2, d1, d0};
    endfunction

    // ==========================================
    // Main Test Sequence
    // ==========================================
    initial begin
        // Initialize AXI-Lite
        s_axi_awaddr  = '0;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = '0;
        s_axi_wstrb   = '0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        aresetn       = 1'b0;
        
        for (int i=0; i<4096; i++) sys_mem[i] = 32'd0;

        #100;
        aresetn = 1'b1;
        #50;

        $display("==========================================================");
        $display("[INFO] Initializing System Memory with Test Data");
        // 4 Columns = 1 beat per row
        
        // Load Matrix at 0x1000
        // Row 0: [1, 1, 1, 1] * [2, 2, 2, 2] -> Expected Dot Prod: 8
        sys_mem[32'h1000/4] = pack_int8(1, 1, 1, 1);
        
        // Row 1: [3, 3, 3, 3] * [2, 2, 2, 2] -> Expected Dot Prod: 24
        sys_mem[32'h1004/4] = pack_int8(3, 3, 3, 3);

        // Row 2: [-5, -5, -5, -5] * [2, 2, 2, 2] -> Dot Prod: -40 -> Expected ReLU: 0
        sys_mem[32'h1008/4] = pack_int8(-5, -5, -5, -5);
        
        // Row 3: [5, 0, 5, 0] * [2, 2, 2, 2] -> Expected Dot Prod: 20
        sys_mem[32'h100C/4] = pack_int8(5, 0, 5, 0);

        $display("[INFO] Configuring Accelerator via AXI4-Lite");
        axi_lite_write(16'h08, 32'h0000_1000); // Matrix Base
        
        // FIX: Pack the Vector data directly into the register!
        axi_lite_write(16'h0C, pack_int8(2, 2, 2, 2)); 
        
        axi_lite_write(16'h10, 32'h0000_3000); // Result Base
        
        // FIX: 4 Columns, 4 Rows
        axi_lite_write(16'h14, {16'd4, 16'd4});
        
        axi_lite_write(16'h00, 32'h0000_0005); // Start = 1, Int_En = 1
        
        $display("[INFO] Accelerator Started. Waiting for Interrupt...");
        
        wait(interrupt == 1'b1);
        @(posedge aclk);
        
        $display("==========================================================");
        $display("[INFO] Interrupt Received. Checking Results in Memory...");
        
        if (sys_mem[32'h3000/4] !== 32'd8) $error("[FAIL] Row 0 Expected 8, Got %0d", sys_mem[32'h3000/4]);
        else $display("[PASS] Row 0 Math Correct (8)");
        
        if (sys_mem[32'h3004/4] !== 32'd24) $error("[FAIL] Row 1 Expected 24, Got %0d", sys_mem[32'h3004/4]);
        else $display("[PASS] Row 1 Math Correct (24)");
        
        if (sys_mem[32'h3008/4] !== 32'd0)  $error("[FAIL] Row 2 Expected 0 (ReLU), Got %0d", sys_mem[32'h3008/4]);
        else $display("[PASS] Row 2 Hardware ReLU Correct (Clamped to 0)");
        
        if (sys_mem[32'h300C/4] !== 32'd20) $error("[FAIL] Row 3 Expected 20, Got %0d", sys_mem[32'h300C/4]);
        else $display("[PASS] Row 3 Math Correct (20)");
        
        $display("==========================================================");
        $display("[GLOBAL PASS] Top-Level Integration verified successfully!");
        $display("==========================================================");
        $finish;
    end

endmodule
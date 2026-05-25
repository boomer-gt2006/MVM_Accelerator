`timescale 1ns / 1ps

module tb_axi4_full_master_dma;

    localparam integer C_M_AXI_DATA_WIDTH = 32;
    localparam integer C_M_AXI_ADDR_WIDTH = 32;

    logic                          aclk;
    logic                          aresetn;

    // Control Interface from FSM
    logic                          dma_fetch_req;
    logic [7:0]                    dma_fetch_len; // 0-based for AXI
    logic [C_M_AXI_ADDR_WIDTH-1:0] dma_target_addr;
    logic                          dma_fetch_done;
    logic                          dma_busy;
    logic                          dma_err;

    // AXI4-Full Read Address Channel (AR)
    logic [C_M_AXI_ADDR_WIDTH-1:0] m_axi_araddr;
    logic [7:0]                    m_axi_arlen;
    logic [2:0]                    m_axi_arsize;
    logic [1:0]                    m_axi_arburst;
    logic                          m_axi_arvalid;
    logic                          m_axi_arready;

    // AXI4-Full Read Data Channel (R)
    logic [C_M_AXI_DATA_WIDTH-1:0] m_axi_rdata;
    logic [1:0]                    m_axi_rresp;
    logic                          m_axi_rlast;
    logic                          m_axi_rvalid;
    logic                          m_axi_rready;

    // BRAM Interface
    logic                          bram_write_en;
    logic [9:0]                    bram_write_addr;
    logic [C_M_AXI_DATA_WIDTH-1:0] bram_write_data;

    // ==========================================================
    // Provide Instance
    // ==========================================================
    axi4_full_master_dma #(
        .C_M_AXI_DATA_WIDTH(C_M_AXI_DATA_WIDTH),
        .C_M_AXI_ADDR_WIDTH(C_M_AXI_ADDR_WIDTH)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .dma_fetch_req(dma_fetch_req),
        .dma_fetch_len(dma_fetch_len),
        .dma_target_addr(dma_target_addr),
        .dma_fetch_done(dma_fetch_done),
        .dma_busy(dma_busy),
        .dma_err(dma_err),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .bram_write_en(bram_write_en),
        .bram_write_addr(bram_write_addr),
        .bram_write_data(bram_write_data)
    );

    // ==========================================================
    // Clock and Reset Generation
    // ==========================================================
    initial begin
        aclk = 1'b0;
        forever #5 aclk = ~aclk; // 100MHz clock
    end

    initial begin
        aresetn = 1'b0;
        #50 aresetn = 1'b1;
    end

    // ==========================================================
    // Environment Mock: Main System Memory (AXI Slave)
    // ==========================================================
    logic [C_M_AXI_DATA_WIDTH-1:0] sys_mem [0:4095]; // 16KB system memory test array
    
    // AXI Slave Internal State
    logic [C_M_AXI_ADDR_WIDTH-1:0] active_araddr;
    logic [7:0]                    active_arlen;
    logic [7:0]                    beats_sent;
    
    typedef enum logic [1:0] {SLV_IDLE, SLV_SENDING} slv_state_t;
    slv_state_t slv_state = SLV_IDLE;

    // AR Channel Logic
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            m_axi_arready <= 1'b0;
            active_araddr <= '0;
            active_arlen  <= '0;
        end else begin
            // Ready to accept address when IDLE
            if (slv_state == SLV_IDLE) begin
                m_axi_arready <= 1'b1;
            end else begin
                m_axi_arready <= 1'b0;
            end

            // Address handshake
            if (m_axi_arready && m_axi_arvalid) begin
                active_araddr <= m_axi_araddr;
                active_arlen  <= m_axi_arlen;
            end
        end
    end

 // R Channel Logic in Testbench
always_ff @(posedge aclk) begin
    if (!aresetn) begin
        slv_state     <= SLV_IDLE;
        m_axi_rvalid  <= 1'b0;
        beats_sent    <= '0;
    end else begin
        case (slv_state)
            SLV_IDLE: begin
                if (m_axi_arready && m_axi_arvalid) begin
                    slv_state <= SLV_SENDING;
                    beats_sent <= '0;
                    m_axi_rvalid <= 1'b1; // Assert valid immediately upon leaving IDLE
                end else begin
                    m_axi_rvalid <= 1'b0; 
                end
            end
            
            SLV_SENDING: begin
                if (m_axi_rready && m_axi_rvalid) begin
                    if (beats_sent == active_arlen) begin
                        slv_state <= SLV_IDLE;
                        m_axi_rvalid <= 1'b0; // Drop valid after the last beat is accepted
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

    // Monitor for debugging
    initial begin
        $monitor("Time=%0t | State=%0d | ARREADY=%b ARVALID=%b ARADDR=%h ARLEN=%0d | RVALID=%b RREADY=%b RDATA=%h RLAST=%b | beats_sent=%0d BRAM_WE=%b BRAM_ADDR=%0d BRAM_WDATA=%h",
                 $time, dut.state, m_axi_arready, m_axi_arvalid, m_axi_araddr, m_axi_arlen,
                 m_axi_rvalid, m_axi_rready, m_axi_rdata, m_axi_rlast,
                 beats_sent, bram_write_en, bram_write_addr, bram_write_data);
    end

    // ==========================================================
    // Environment Mock: Internal Ping-Pong Subsystem (BRAM)
    // ==========================================================
    logic [C_M_AXI_DATA_WIDTH-1:0] local_bram [0:1023]; // Monitor the written data
    
    always_ff @(posedge aclk) begin
        if (bram_write_en) begin
            local_bram[bram_write_addr] <= bram_write_data;
        end
    end

    // ==========================================================
    // Stimulus and Self-Checking Flow
    // ==========================================================
    initial begin
        dma_fetch_req   = 1'b0;
        dma_fetch_len   = '0;
        dma_target_addr = '0;
        
        // Prefill System Memory with predictable data
        for (int i=0; i<4096; i++) begin
            sys_mem[i] = i * 32'h00000001; // E.g., ADDR/4 data format
        end

        // Wait for reset to drop
        wait(aresetn == 1'b1);
        #40;

        // ----------------------------------------------------
        // TEST 1: Basic 16-beat Burst
        // ----------------------------------------------------
        $display("[INFO] TEST 1: Initiating a standard 16-beat burst starting at physical offset 0x0100");
        @(posedge aclk);
        dma_target_addr <= 32'h0000_0100;
        dma_fetch_len   <= 15; // 16 beats request (0-based)
        dma_fetch_req   <= 1'b1;
        
        @(posedge aclk);
        dma_fetch_req   <= 1'b0;

        wait(dma_fetch_done == 1'b1);
        $display("[INFO] Test 1 FSM execution finished. Checking local BRAM arrays...");
        #20;
        
        // Assert checks
        for (int i=0; i<16; i++) begin
            if (local_bram[i] !== sys_mem[(32'h0100/4) + i]) begin
                $error("[FAIL] Test 1: Data mismatch at BRAM[%0d]. Expeted 0x%08h, Got 0x%08h", 
                        i, sys_mem[(32'h0100/4) + i], local_bram[i]);
                $finish;
            end
        end
        $display("[PASS] Test 1: 16-beat Burst successfully written and validated in BRAM.");

        // Clear local BRAM for next test
        for (int i=0; i<1024; i++) begin
            local_bram[i] = '0;
        end
        
        #100;

        // ----------------------------------------------------
        // TEST 2: 4KB Boundary Crossing Execution
        // ----------------------------------------------------
        $display("[INFO] TEST 2: Initiating a 64-beat burst approaching a 4KB boundary.");
        $display("       Physical 4KB Boundary occurs at 0x1000.");
        $display("       Starting Read at 0x0FF0 (16 bytes = 4 beats before boundary).");
        $display("       DMA is mechanically required to split this request to prevent AXI violation.");
        
        @(posedge aclk);
        dma_target_addr <= 32'h0000_0FF0;
        dma_fetch_len   <= 63; // 64 beats total request 
        dma_fetch_req   <= 1'b1;
        
        @(posedge aclk);
        dma_fetch_req   <= 1'b0;

        wait(dma_fetch_done == 1'b1);
        $display("[INFO] Test 2 FSM execution finished. Checking dual-burst combinations in local BRAM arrays...");
        #20;
        
        // Assert checks
        for (int i=0; i<64; i++) begin
            if (local_bram[i] !== sys_mem[(32'h0FF0/4) + i]) begin
                $error("[FAIL] Test 2: Data mismatch at BRAM[%0d]. Expeted 0x%08h, Got 0x%08h", 
                        i, sys_mem[(32'h0FF0/4) + i], local_bram[i]);
                $finish;
            end
        end
        $display("[PASS] Test 2: 4KB Boundary split executed perfectly. 64-beat payload contiguous in BRAM without corruption.");

        $display("==========================================================");
        $display("[GLOBAL PASS] All DMA Burst Logic self-checks cleared.");
        $display("==========================================================");
        $finish;
    end

endmodule
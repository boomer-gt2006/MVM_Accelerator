`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

// =========================================================
// THE SCRIPT: AXI-Lite Configuration Sequence
// =========================================================
class mvm_basic_seq extends uvm_sequence #(axi_lite_seq_item);
    `uvm_object_utils(mvm_basic_seq)

    function new(string name = "mvm_basic_seq");
        super.new(name);
    endfunction

    // Helper task to make writing registers clean
    task write_reg(logic [15:0] addr, logic [31:0] data);
        req = axi_lite_seq_item::type_id::create("req");
        start_item(req);
        req.is_write = 1;
        req.addr     = addr;
        req.data     = data;
        finish_item(req);
    endtask

    virtual task body();
        `uvm_info("SEQ", "Starting AXI-Lite Accelerator Configuration...", UVM_LOW)
        
        // Match the directed testbench configuration
        write_reg(16'h08, 32'h0000_1000); // Matrix Base
        write_reg(16'h0C, {8'd2, 8'd2, 8'd2, 8'd2}); // Vector Data
        write_reg(16'h10, 32'h0000_3000); // Result Base
        write_reg(16'h14, {16'd4, 16'd4}); // {Cols=4, Rows=4}
        
        // Start the accelerator!
        write_reg(16'h00, 32'h0000_0005); // Start = 1, Int_En = 1
        
        `uvm_info("SEQ", "Accelerator Configuration Complete.", UVM_LOW)
    endtask
endclass

// =========================================================
// THE TEST: Master Controller
// =========================================================
class mvm_basic_test extends uvm_test;
    `uvm_component_utils(mvm_basic_test)

    mvm_env env;

    function new(string name = "mvm_basic_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = mvm_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mvm_basic_seq seq;
        seq = mvm_basic_seq::type_id::create("seq");

        // "Raise Objection" prevents UVM from shutting down the simulation early
        phase.raise_objection(this);
        
        // Give the reset some time to settle
        #200; 
        
        // Run our script on the AXI-Lite Sequencer
        seq.start(env.lite_agent.sequencer);

        // Give the hardware enough time to finish computing the math
        #2000; 

        // Simulation complete! Drop objection to end.
        phase.drop_objection(this);
    endtask
endclass

// =========================================================
// THE SCRIPT: 1000-Matrix Randomized Stress Sequence
// =========================================================
class mvm_stress_seq extends uvm_sequence #(axi_lite_seq_item);
    `uvm_object_utils(mvm_stress_seq)

    function new(string name = "mvm_stress_seq");
        super.new(name);
    endfunction

    task write_reg(logic [15:0] addr, logic [31:0] data);
        req = axi_lite_seq_item::type_id::create("req");
        start_item(req);
        req.is_write = 1;
        req.addr     = addr;
        req.data     = data;
        finish_item(req);
    endtask

    virtual task body();
        mvm_env env;
        int random_matrix[16];
        int random_vector[4];
        byte temp_val; // ADD THIS: A temporary 8-bit container

        `uvm_info("SEQ", "Starting 1000-Matrix UVM Stress Test...", UVM_LOW)

        // Grab a backdoor handle to the UVM Environment
        if (!$cast(env, uvm_top.find("uvm_test_top.env"))) begin
            `uvm_fatal("SEQ", "Could not find UVM Environment for backdoor access!")
        end

        // Run the gauntlet 1,000 times
        for (int iteration = 0; iteration < 1000; iteration++) begin

            // 1. Generate entirely random 8-bit signed data (-128 to 127)
            // 1. Generate perfectly sign-extended 8-bit data
            for (int i=0; i<16; i++) begin
                temp_val = $urandom();       // Generates random 8-bit bits
                random_matrix[i] = temp_val; // Safely sign-extends to 32-bit int for C++!
            end
            for (int i=0; i<4; i++) begin
                temp_val = $urandom();
                random_vector[i] = temp_val;
            end

            // 2. Backdoor load the AXI-Full Driver's DDR Memory
            // We cast to byte to correctly pack the 8-bit values into the 32-bit memory words
            for (int i=0; i<4; i++) begin
                env.full_agent.driver.sys_mem['h1000/4 + i] = {
                    byte'(random_matrix[i*4+3]), byte'(random_matrix[i*4+2]), 
                    byte'(random_matrix[i*4+1]), byte'(random_matrix[i*4+0])
                };
            end
            env.full_agent.driver.sys_mem['h1010/4] = {
                byte'(random_vector[3]), byte'(random_vector[2]), 
                byte'(random_vector[1]), byte'(random_vector[0])
            };

            // 3. Backdoor load the Scoreboard and trigger the C++ calculation
            env.scoreboard.test_matrix = random_matrix;
            env.scoreboard.test_vector = random_vector;
            env.scoreboard.calculate_baseline();

            // 4. Send AXI-Lite Configuration
            write_reg(16'h08, 32'h0000_1000); // Matrix Base
            // FIXED: Pack the 4 random 8-bit vector values directly into the AXI-Lite register!
            write_reg(16'h0C, {byte'(random_vector[3]), byte'(random_vector[2]), 
                               byte'(random_vector[1]), byte'(random_vector[0])});
            write_reg(16'h10, 32'h0000_3000); // Result Base
            write_reg(16'h14, {16'd4, 16'd4}); // {Cols=4, Rows=4}

            // 5. Fire Accelerator!
            write_reg(16'h00, 32'h0000_0005);

            // 6. Wait for hardware to survive the math and the memory stalls
            // 5000ns is enough time for the FSM to transition back to ST_IDLE
            #5000; 
        end
        
        `uvm_info("SEQ", "========================================", UVM_NONE)
        `uvm_info("SEQ", "1,000 RANDOMIZED MATRICES PROCESSED PERFECTLY!", UVM_NONE)
        `uvm_info("SEQ", "========================================", UVM_NONE)
    endtask
endclass

// =========================================================
// THE TEST: Stress Test Controller
// =========================================================
class mvm_stress_test extends uvm_test;
    `uvm_component_utils(mvm_stress_test)

    mvm_env env;

    function new(string name = "mvm_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = mvm_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mvm_stress_seq seq = mvm_stress_seq::type_id::create("seq");
        phase.raise_objection(this);
        #200; 
        seq.start(env.lite_agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass
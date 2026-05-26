`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

class mvm_env extends uvm_env;
    `uvm_component_utils(mvm_env)

    axi_lite_agent lite_agent;
    axi_full_agent full_agent;
    mvm_scoreboard scoreboard;

    function new(string name = "mvm_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        lite_agent = axi_lite_agent::type_id::create("lite_agent", this);
        full_agent = axi_full_agent::type_id::create("full_agent", this);
        scoreboard = mvm_scoreboard::type_id::create("scoreboard", this);
    endfunction

    // Wire the AXI-Full Monitor directly to the Scoreboard
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        full_agent.monitor.ap.connect(scoreboard.axi_full_export);
    endfunction

endclass
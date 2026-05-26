# ==============================================================================
# Vivado Project Build Script for Standalone INT8 SIMD MVM Accelerator
# ==============================================================================
set env(xv_cxl_win_path) ""
set PROJ_NAME "mvm_accelerator"
set PROJ_DIR "C:/Users/gt111/Desktop/MVM_Accelerator/build/vivado_project"

# Targeting Zybo Z7-10 as requested
set PART "xc7z010clg400-1"

# Create the project
create_project -force $PROJ_NAME $PROJ_DIR -part $PART

# Configure project properties
set_property target_language Verilog [current_project]
set_property default_lib work [current_project]

# Define base paths relative to the scripts folder
set RTL_DIR "C:/Users/gt111/Desktop/MVM_Accelerator/rtl"
set TB_DIR "C:/Users/gt111/Desktop/MVM_Accelerator/tb"
set CONSTRAINTS_DIR "C:/Users/gt111/Desktop/MVM_Accelerator/constraints"

puts "INFO: Vivado project $PROJ_NAME created in $PROJ_DIR"

# ==============================================================================
# Add Sources
# ==============================================================================

# --- Week 1: Control Interfaces and Scalar Baseline ---
add_files $RTL_DIR/mvm_accelerator_top.sv
add_files $RTL_DIR/axi4_lite_slave.sv
add_files $RTL_DIR/scalar_datapath.sv

# --- Week 2: Memory Subsystems and DMA Foundations ---
add_files $RTL_DIR/ping_pong_bram.sv
add_files $RTL_DIR/axi4_full_master_dma.sv

# --- Week 3: SIMD Expansion and Adder Tree Pipelining ---
add_files $RTL_DIR/simd_datapath.sv

# --- Week 4: Central FSM and Concurrent Orchestration ---
add_files $RTL_DIR/controller_fsm.sv

# ==============================================================================
# Add Simulation Sources (Directed Testbenches)
# ==============================================================================
add_files -fileset sim_1 $TB_DIR/tb_scalar_datapath.sv
add_files -fileset sim_1 $TB_DIR/tb_axi4_full_master_dma.sv
add_files -fileset sim_1 $TB_DIR/tb_simd_datapath.sv
add_files -fileset sim_1 $TB_DIR/tb_controller_fsm.sv
add_files -fileset sim_1 $TB_DIR/tb_mvm_accelerator_top.sv

puts "INFO: Core source addition complete."

# ==============================================================================
# UVM & DPI-C Verification Environment Setup
# ==============================================================================
set UVM_DIR $TB_DIR/uvm

# 1. Add the C++ Golden Reference Model (Vivado auto-detects .cpp)
add_files -fileset sim_1 $UVM_DIR/mvm_reference_model.cpp

# 2. Add the SystemVerilog DPI Package
add_files -fileset sim_1 $UVM_DIR/mvm_dpi_pkg.sv

# 3. Enable UVM Library Compilation in Vivado Simulator
set_property -name {xsim.compile.xvlog.more_options} -value {-L uvm} -objects [get_filesets sim_1]
set_property -name {xsim.elaborate.xelab.more_options} -value {-L uvm} -objects [get_filesets sim_1]

# 4. Add ONLY the SystemVerilog AXI Interfaces (Hardware bundles)
add_files -fileset sim_1 $UVM_DIR/axi4_lite_if.sv
add_files -fileset sim_1 $UVM_DIR/axi4_full_if.sv

# 5. Add the Physical UVM Wrapper (which contains the `include statements)
add_files -fileset sim_1 $TB_DIR/tb_uvm_top.sv

# 6. Tell Vivado where to look for the `include statements (Agents, Scoreboard, etc.)
set_property include_dirs $UVM_DIR [get_filesets sim_1]

# 7. Set the active simulation top module to the UVM Wrapper
set_property top tb_uvm_top [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "INFO: UVM Environment linked successfully."
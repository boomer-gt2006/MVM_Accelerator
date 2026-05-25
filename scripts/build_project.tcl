# ==============================================================================
# Vivado Project Build Script for Standalone INT8 SIMD MVM Accelerator
# ==============================================================================

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
# Note: These add_files commands will be uncommented and updated step-by-step
# as we progress through the weekly tracker.
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
# add_files $RTL_DIR/adder_tree.sv

# --- Week 4: Central FSM and Concurrent Orchestration ---
add_files $RTL_DIR/controller_fsm.sv

# ==============================================================================
# Set Top Module
# ==============================================================================
# set_property top mvm_accelerator_top [current_fileset]
# update_compile_order -fileset sources_1

# ==============================================================================
# Add Simulation Sources
# ==============================================================================
add_files -fileset sim_1 $TB_DIR/tb_scalar_datapath.sv
add_files -fileset sim_1 $TB_DIR/tb_axi4_full_master_dma.sv
add_files -fileset sim_1 $TB_DIR/tb_simd_datapath.sv
add_files -fileset sim_1 $TB_DIR/tb_controller_fsm.sv
add_files -fileset sim_1 $TB_DIR/tb_mvm_accelerator_top.sv
# set_property top mvm_accelerator_tb [get_filesets sim_1]
# update_compile_order -fileset sim_1

puts "INFO: Source addition complete. Ready for compilation / simulation."

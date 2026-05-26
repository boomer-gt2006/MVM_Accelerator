# Implementation & Verification Tracker

This document tracks the phased 5-week implementation plan for the Standalone INT8 SIMD Matrix-Vector Hardware Accelerator.

## Week 1: Control Interfaces and Scalar Baseline
**Goal:** Establish physical framework and basic mathematical control group.
- [x] Create `mvm_accelerator_top.sv` top-level wrapper with AXI parameterization.
- [x] Design the AXI4-Lite slave interface terminating the control bus.
- [x] Implement control memory map (`CONTROL_REG`, `STATUS_REG`, `MATRIX_BASE`, `VECTOR_BASE`, `RESULT_BASE`, `DIM_CONFIG`).
- [x] Create a basic scalar (non-SIMD) datapath.
- [x] Implement temporal accumulator and hardware ReLU logic.
- [x] **Verification:** Host can read/write all AXI4-Lite registers perfectly. Scalar mathematics evaluate correctly.

## Week 2: Memory Subsystems and DMA Foundations
**Goal:** Realize internal storage and external burst fetching capabilities.
- [x] Instantiate the True Dual-Port Ping-Pong BRAM subsystem.
- [x] Design the autonomous AXI4-Full Master DMA engine.
- [x] Implement AXI read channel address incrementing and burst fetch logic.
- [x] Implement arithmetic boundary checking to strictly enforce the AXI 4KB crossing constraint.
- [x] **Verification:** DMA correctly requests 256-beat bursts and routes data accurately into local BRAM arrays without protocol faults.

## Week 3: SIMD Expansion and Adder Tree Pipelining
**Goal:** Maximize datapath throughput and ensure timing closure.
- [x] Replace scalar datapath with the 32-bit word-packed SIMD architecture.
- [x] Implement 4x parallel INT8 multiplier units.
- [x] Construct the pipelined logarithmic binary adder tree for spatial reduction.
- [x] Connect the adder tree to the temporal accumulator.
- [x] **Verification:** SIMD correctly unpacks data, computes 4 parallel products, and chronologically accumulates without arithmetic overflow.

## Week 4: Central FSM and Concurrent Orchestration
**Goal:** Solve memory starvation via concurrent buffer management.
- [x] Implement the Centralized Controller FSM (`STATE_IDLE`, `STATE_CFG_LOAD`, `STATE_DMA_BURST_PING`, `STATE_COMPUTE_PING_BURST_PONG`, etc.).
- [x] Integrate multiplexer logic for continuous Ping-Pong buffer swapping.
- [x] Orchestrate AXI4-Full master write channel for finalized scalar result write-back.
- [x] Connect interrupt signaling (`DONE` state).
- [x] **Verification:** FSM correctly oscillates Ping/Pong states. Datapath is successfully fed without starvation or race conditions.

## Week 5: UVM Verification and Hardware Benchmarking
**Goal:** Prove absolute robustness and evaluate physical performance.
- [x] Construct the Universal Verification Methodology (UVM) testbench framework.
- [x] Implement DPI-C C++ high-level reference model for the UVM Scoreboard.
- [x] Embed temporal SystemVerilog Assertions (SVA) natively within RTL modules.
- [x] Inject targeted edge-case UVM sequences (4KB boundaries, aggressive AXI backpressure, max-value ReLU clamping).
- [ ] Synthesize RTL for Xilinx Zynq-7000 (Zybo Z7-10) FPGA architecture.
- [ ] **Verification:** 100% UVM randomized test pass rate. Zero SVA failures. DSP48E1 block inference confirmed. Roofline model performance metrics documented.

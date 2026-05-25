# Standalone INT8 SIMD Matrix-Vector Hardware Accelerator

## Overview
This repository contains the architectural framework and SystemVerilog implementation for a custom, standalone INT8 Single Instruction Multiple Data (SIMD) hardware accelerator designed specifically for Matrix-Vector Multiplication (MVM) operations. The design operates strictly as an isolated "black box" IP core, interfacing with external systems exclusively via the industry-standard AMBA AXI protocol.

## Core Architectural Features

* **High-Throughput Datapath:** Utilizes an INT8 SIMD architecture. It aggressively employs word-packing, mapping four discrete 8-bit integers into a standard 32-bit datapath, effectively quadrupling theoretical MAC operations per cycle.
* **Logarithmic Adder Tree:** Spatially reduces parallel partial products using a highly pipelined binary adder tree to maintain strict timing closure and a high clock frequency.
* **Memory Latency Hiding:** Systematically mitigates external memory bottlenecks using localized True Dual-Port Block RAM (BRAM) configured as a "Ping-Pong" double buffer. This scheme masks Direct Memory Access (DMA) latency behind active computation cycles.
* **AMBA AXI Integration:** 
  * **AXI4-Lite:** Provides a robust memory-mapped control interface for host CPU configuration (dimensions, base addresses, operation triggering) and status polling.
  * **AXI4-Full:** Features an autonomous master DMA engine capable of multi-beat burst transactions to efficiently fetch weight matrices and write back activation results.
* **Non-Linear Activation:** Incorporates a fast hardware Rectified Linear Unit (ReLU) for temporal accumulator clamping.

## Development & Verification Methodology

The project adheres to a strict 5-week phased implementation plan (see `TRACKER.md`), systematically transitioning from basic AXI control and scalar math to full concurrent FSM orchestration.

Verification is paramount, utilizing a comprehensive Universal Verification Methodology (UVM) framework augmented by SystemVerilog Assertions (SVA) to prove both protocol compliance (e.g., 4KB boundary constraints) and mathematical correctness under high-stress conditions like randomized backpressure. Hardware capacity and efficiency are evaluated using the empirical Roofline Model.

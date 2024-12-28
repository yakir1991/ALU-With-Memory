# ALU-With-Memory

**ALU With Memory**

---

## Table of Contents
1. [Introduction](#introduction)  
2. [Requirements](#requirements)  
3. [Design Description](#design-description)  
4. [Verification Environment](#verification-environment)  
   - [Components](#components)  
   - [Coverage](#coverage)  
   - [Assertions](#assertions)  
5. [How to Run](#how-to-run)  
6. [Directory Structure](#directory-structure)  
7. [Future Improvements](#future-improvements)  
8. [License](#license)

---

## Introduction
This **ALU With Memory** project demonstrates a simple SystemVerilog design that combines:
- A small **memory** with 4 locations (2-bit address) and 8-bit data width,
- An **ALU** capable of performing basic arithmetic operations (ADD, SUB, MUL, DIV),
- A set of **registers** (A, B, OPERATION, EXECUTE) for controlling and triggering the ALU,
- A **verification environment** that includes random and directed tests, functional coverage, and assertions.

---

## Requirements
1. **Memory and ALU**:
   - `ADDR_WIDTH = 2` (4 addresses: 0..3)  
   - `DATA_WIDTH = 8` (8-bit data)  
   - 16-bit `res_out` for ALU results

2. **Register Map**:
   - **0** => A_REG (8-bit operand A)  
   - **1** => B_REG (8-bit operand B)  
   - **2** => OPERATION_REG (bits [2:0] select ALU operation; [7:3] reserved)  
   - **3** => EXECUTE_REG (bit [0] triggers ALU; [7:1] reserved)

3. **Reset Behavior**:
   - Memory initialized to `0xFF` on reset  
   - ALU result reset to `0x0000`

4. **ALU Operations**:
   - `0`: result = 0  
   - `1`: result = A + B  
   - `2`: result = A - B  
   - `3`: result = A * B  
   - `4`: result = A / B (or `0xDEAD` if B=0)  
   - Any other => Keep previous result

---

## Design Description
- **`memory.sv`**: Implements a 4x8-bit memory and an ALU in the same module.  
- On each read/write, address/control signals select the desired register.  
- When `EXECUTE=1`, the ALU computes according to `OPERATION_REG` and updates `res_out`.

---

## Verification Environment

### Components
1. **`interface.sv`**: Declares signals (enable, rd_wr, addr, etc.) and includes basic timing assertions.  
2. **`transaction.sv`**: Defines the `transaction` class with constraints for address, data, read vs. write, etc.  
3. **`generator.sv`**: Creates and randomizes transactions, sends them to the driver via a mailbox.  
4. **`driver.sv`**: Drives signals into the DUT based on the received transactions.  
5. **`monitor_in.sv` / `monitor_out.sv`**: Observes inputs/outputs of the DUT, passes info to the scoreboard.  
6. **`scoreboard.sv`**: Tracks expected memory state and ALU results; compares actual vs. expected; logs Pass/Fail.  
7. **`test.sv`** / **`direct_test.sv`**: Coordinates the environment setup and runs random or directed tests.

### Coverage
- Functional coverage is added in the scoreboard (or a separate covergroup) to ensure register addresses, operations, and corner cases (e.g. DIV by zero) are exercised.

### Assertions
- **Timing Assertions** (valid read/write checks) in `interface.sv`.  
- **Protocol Checks** (e.g., stable address, no unknown signals) to ensure the DUT behaves correctly under various conditions.

---

## How to Run
1. **Compile**:
   ```bash
   vcs -full64 -sverilog -f build.list -timescale=1ns/1ns +vcs+flush+all +warn=all
   ```
   (Adjust compilation flags as needed.)

2. **Simulate**:
   ```bash
   ./simv +vcs+lic+wait
   ```
   Waveform dumping and coverage options can be added (e.g. `-cm line+cond+tgl+branch`).

3. **View Results**:
   - Scoreboard logs (PASS/FAIL counts, ALU checks).  
   - Assertions: any violations print errors.  
   - Coverage: run `urg -dir simv.vdb` to generate coverage reports (if enabled).

---

## Directory Structure
```
├── design.sv
├── memory.sv
├── interface.sv
├── transaction.sv
├── generator.sv
├── driver.sv
├── monitor_in.sv
├── monitor_out.sv
├── scoreboard.sv
├── environment.sv
├── test.sv
├── direct_test.sv
├── build.list
└── README.md
```
- **`design.sv`, `memory.sv`**: DUT logic.  
- **`interface.sv`**: Declares signals, assertions.  
- **`transaction.sv`, `generator.sv`, `driver.sv`**: Transaction-level stimulus generation and driving.  
- **`monitor_in.sv`, `monitor_out.sv`, `scoreboard.sv`**: Observers and result-checking.  
- **`test.sv`, `direct_test.sv`**: Test control (random/directed).  
- **`build.list`**: Compilation order.

---

## Future Improvements
- **Pipeline the ALU** for multi-cycle operations.  
- **UVM Integration** for a standardized verification methodology.  
- **Extended Coverage**: Additional data patterns (e.g. `0xFF + 1`, `0x80 - 0x01`, etc.).  
- **Random Resets** during ALU operations to check robustness.

---

**Enjoy exploring the ALU With Memory project!**  
Contributions and feedback are welcome.

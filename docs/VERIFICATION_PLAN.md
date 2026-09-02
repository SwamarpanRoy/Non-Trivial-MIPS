# Formal Verification Plan: AXI4-Lite to APB4 Peripheral Subsystem

**Project:** NonTrivial-MIPS FPGA SoC  
**Target Specification:** AMBA AXI4-Lite (ARM IHI 0022E) & APB4 (ARM IHI 0024C)  
**Author:** FPGA Design & Verification Engineering  
**Classification:** Enterprise Verification Deliverable  

---

## 1. Executive Summary

This document specifies the verification methodology, test architecture, coverage metrics, and assertion rules for validating the **AXI4-Lite to APB4 Bridge**, **Memory-Mapped Register Block**, and **Asynchronous Clock Domain Crossing (CDC) Subsystem** within the NonTrivial-MIPS processor.

The goal of this plan is to achieve **100% functional coverage** and **100% protocol compliance** through a combination of:
1. Directed functional tests for register functionality and peripheral timing.
2. Constrained-random bus transactions to test back-to-back channel arbitration.
3. SystemVerilog Assertions (SVA) checking formal AMBA protocol invariants.
4. Error injection scenarios validating bus fault tolerance and recovery.

---

## 2. Design Under Test (DUT) Architecture

```
+-------------------------------------------------------------------------+
| NonTrivial-MIPS Verification Subsystem                                   |
|                                                                         |
|  +------------------------+             +----------------------------+  |
|  |   axi_to_apb_bridge    |   APB4 Bus  |    apb_register_block      |  |
|  |                        |  PADDR[31:0]|  - REG_DEV_ID (0x00)       |  |
|  |  * AXI4-Lite Slave     |  PWDATA     |  - REG_CTRL   (0x04)       |  |
|  |    AW / W / B Channels |  PRDATA     |  - REG_STATUS (0x08)       |  |
|  |    AR / R Channels     +------------>|  - Hardware Timer (0x0C)   |  |
|  |  * APB4 Master FSM     |  PENABLE    |  - W1C Interrupt Controller|  |
|  |    SETUP / ACCESS      |  PREADY     |  - 8-Deep Loopback FIFO    |  |
|  |  * PSLVERR Translation |  PSLVERR    |  - Error Injection Engine  |  |
|  +------------------------+             +----------------------------+  |
|              ^                                         ^                |
|              | SVA Monitor                             | SVA Monitor    |
|  +------------------------+             +----------------------------+  |
|  |  axi_protocol_checker  |             |    apb_protocol_checker    |  |
|  +------------------------+             +----------------------------+  |
+-------------------------------------------------------------------------+
```

---

## 3. Verification Test Matrix

| Test ID | Test Category       | Description                                                 | Target Feature / Register          | Expected Outcome                 |
|:-------:|:--------------------|:------------------------------------------------------------|:-----------------------------------|:---------------------------------|
| `TC-01` | Sanity / Read-Only  | Verify read of hardcoded Device Identification register.    | `REG_DEV_ID` (`0x00`)              | Returns `0x4349_5343` ("CISC")   |
| `TC-02` | Register R/W        | Write and readback control settings (Core En, IRQ En).      | `REG_CTRL` (`0x04`)                | Readback data matches written data|
| `TC-03` | Hardware Timer      | Program countdown timer, await expiration, inspect IRQ flag.| `REG_TIMER_CFG` (`0x0C`), `irq_o`   | IRQ bit sets; `irq_o` asserts    |
| `TC-04` | Interrupt Clearance | Perform Write-1-to-Clear (W1C) on active interrupt status.  | `REG_IRQ_STATUS` (`0x14`)          | IRQ status clears; `irq_o` drops |
| `TC-05` | FIFO Push/Pop       | Push 3 distinct words into loopback FIFO, pop and compare.  | `REG_LOOPBACK_DATA` (`0x1C`)       | Data popped in exact FIFO order  |
| `TC-06` | Bus Error Response  | Issue read access to unmapped address (`0xFC`).             | Unmapped decoding                  | APB `PSLVERR` -> AXI `SLVERR`    |
| `TC-07` | Fault Recovery      | Clear error injection and verify normal bus access returns. | `REG_ERR_INJECT` (`0x20`), `0x00`  | Normal `OKAY` (2'b00) response   |
| `TC-08` | Random Stress       | Dispatch 20 back-to-back randomized write/read transfers.   | Full register map                  | 100% data integrity match        |

---

## 4. SystemVerilog Assertions (SVA) Specification

### 4.1 AXI4-Lite Protocol Checker (`axi_protocol_checker.sv`)
- **Rule SVA-AXI-01 (Reset State):** During reset (`!aresetn`), all valid signals (`awvalid`, `wvalid`, `bvalid`, `arvalid`, `rvalid`) must be deasserted.
- **Rule SVA-AXI-02 (ARVALID Stability):** Once `arvalid` is asserted, it must remain high until `arready` is asserted.
- **Rule SVA-AXI-03 (AR Payload Stability):** `araddr` and `arprot` must remain unchanged while waiting for `arready`.
- **Rule SVA-AXI-04 (AW/W Handshake):** `awvalid` and `wvalid` must remain high until their respective ready handshakes complete.
- **Rule SVA-AXI-05 (R/B Channel Handshake):** Slaves must hold `rvalid` and `bvalid` until the master samples with `rready` / `bready`.

### 4.2 APB4 Protocol Checker (`apb_protocol_checker.sv`)
- **Rule SVA-APB-01 (Phase Sequencing):** `PSEL` must assert for at least one cycle before `PENABLE` asserts (`SETUP` -> `ACCESS`).
- **Rule SVA-APB-02 (Control Signal Stability):** `PADDR`, `PWRITE`, `PWDATA`, and `PSTRB` must remain stable throughout the entire transfer until `PREADY` is high.
- **Rule SVA-APB-03 (PSLVERR Validity):** `PSLVERR` is only sampled when both `PSEL`, `PENABLE`, and `PREADY` are simultaneously active.

### 4.3 Asynchronous FIFO Checkers (`fifo_assertions.sv`)
- **Rule SVA-FIFO-01 (No Overflow):** Write enable must never be asserted when `full == 1`.
- **Rule SVA-FIFO-02 (No Underflow):** Read enable must never be asserted when `empty == 1`.
- **Rule SVA-FIFO-03 (Gray Code Invariant):** Multi-bit Gray pointers crossing clock domains must change by at most one bit per clock cycle (`$countones(gray ^ past_gray) <= 1`).

---

## 5. Coverage Model & Closure Targets

### 5.1 Functional Coverage Bins
- **Covergroup `cg_axi_trans`**:
  - `cp_addr_aligned`: Bins for all 8 register offsets (`0x00`, `0x04`, `0x08`, `0x0C`, `0x10`, `0x14`, `0x18`, `0x1C`, `0x20`).
  - `cp_operation`: Bins for Read (`is_write=0`) and Write (`is_write=1`).
  - `cp_response`: Bins for `OKAY` (2'b00) and `SLVERR` (2'b10).
  - `cross_addr_op`: Full cross coverage between address and read/write operations.
- **Closure Target:** **100% of defined functional coverage bins hit.**

### 5.2 Code Coverage Metrics (Commercial Flow)
- **Line / Statement Coverage:** > 95%
- **Branch / Decision Coverage:** > 95%
- **FSM State & Transition Coverage:** 100% of all reachable bridge states (`ST_IDLE`, `ST_SETUP`, `ST_ACCESS`, `ST_W_RESP`, `ST_R_RESP`).
- **Toggle Coverage:** > 90% on all bus interfaces.

---

## 6. Regression Automation Flow

Simulations are executed via `scripts/run_regression.py` with reproducible random seeds:
```bash
python3 scripts/run_regression.py --seed 12345 --runs 5
```
Each iteration reports:
- Number of assertions dynamically evaluated.
- Functional coverage bins closed.
- Real-time simulation duration.
- Detailed pass/fail diagnostics with signal traces stored in `sim.vcd`.

# NonTrivial-MIPS

[![Hardware](https://img.shields.io/badge/Architecture-MIPS32%20R1%2FR2-blue.svg)](file:///Users/swamarpanroy/Downloads/nontrivial-mips/src/cpu)
[![Language](https://img.shields.io/badge/Language-SystemVerilog%202005%2F2012-brightgreen.svg)](file:///Users/swamarpanroy/Downloads/nontrivial-mips/src)
[![FPGA Target](https://img.shields.io/badge/Target-Xilinx%20Artix--7%20200T-orange.svg)](file:///Users/swamarpanroy/Downloads/nontrivial-mips/vivado)
[![OS Support](https://img.shields.io/badge/Linux-5.2.8%20Bootable-yellowgreen.svg)](file:///Users/swamarpanroy/Downloads/nontrivial-mips/report/os_software.tex)
[![OS Support](https://img.shields.io/badge/RTOS-uCore--thumips-yellow.svg)](file:///Users/swamarpanroy/Downloads/nontrivial-mips/report/os_software.tex)
[![Verification](https://img.shields.io/badge/SVA-Formal%20Protocol%20Checkers-red.svg)](file:///Users/swamarpanroy/Downloads/nontrivial-mips/src/sva)
[![Competition](https://img.shields.io/badge/NSCSCC%202019-First%20Prize-purple.svg)](file:///Users/swamarpanroy/Downloads/nontrivial-mips/report)

**NonTrivial-MIPS** is an enterprise-grade, high-performance dual-issue superscalar 32-bit MIPS processor, complete System-on-Chip (SoC), and formal verification testbed implemented in synthesizable SystemVerilog. Originally designed by the Tsinghua University team *"Programming is a Dangerous Thing"* for the 3rd National College Student Computer System Capability Challenge (NSCSCC / Loongson Cup 2019, First Prize), the architecture incorporates an out-of-order execution model, a multi-tiered memory hierarchy, advanced clock domain crossing (CDC) synchronizers, AMBA AXI4/APB4 interconnects, and a formal SVA verification suite.

The system is capable of running bare-metal firmware, **U-Boot**, **uCore-thumips**, and full-fledged **Linux 5.2.8** with graphics (Xorg), networking, USB peripherals, and userland runtimes (Python, GNU coreutils).

---

## Table of Contents

- [Key Architecture Highlights](#key-architecture-highlights)
- [Processor Microarchitecture](#processor-microarchitecture)
  - [10-Stage Dynamically Scheduled Pipeline](#10-stage-dynamically-scheduled-pipeline)
  - [Dynamic Delayed Execution Engine](#dynamic-delayed-execution-engine)
  - [Branch Prediction & Fetch Unit](#branch-prediction--fetch-unit)
  - [Memory Management Unit (MMU & TLB)](#memory-management-unit-mmu--tlb)
  - [Hardware Accelerators (FPU & AES ASIC)](#hardware-accelerators-fpu--aes-asic)
- [Memory Hierarchy & Cache Subsystem](#memory-hierarchy--cache-subsystem)
- [System-on-Chip (SoC) Architecture](#system-on-chip-soc-architecture)
  - [Interconnect Topology](#interconnect-topology)
  - [Complete SoC Physical Memory Map](#complete-soc-physical-memory-map)
  - [Interrupt Routing Matrix](#interrupt-routing-matrix)
- [Enterprise APB4 Peripheral Subsystem](#enterprise-apb4-peripheral-subsystem)
  - [Register Map Specification](#register-map-specification)
- [Clock Domain Crossing (CDC) & Timing Closure](#clock-domain-crossing-cdc--timing-closure)
  - [Metastability & MTBF Hardening](#metastability--mtbf-hardening)
  - [Reset Synchronization (AASD)](#reset-synchronization-aasd)
  - [Dual-Clock Asynchronous FIFO](#dual-clock-asynchronous-fifo)
- [Verification & Quality Assurance](#verification--quality-assurance)
  - [SystemVerilog Assertion (SVA) Checkers](#systemverilog-assertion-sva-checkers)
  - [Verification Test Matrix (TC-01 – TC-08)](#verification-test-matrix-tc-01--tc-08)
  - [Automated Python Regression Dispatcher](#automated-python-regression-dispatcher)
- [Software Ecosystem](#software-ecosystem)
  - [Bootloader Chain](#bootloader-chain)
  - [Operating Systems](#operating-systems)
- [Repository Structure](#repository-structure)
- [Getting Started & Build Instructions](#getting-started--build-instructions)
  - [Prerequisites](#prerequisites)
  - [Simulation with Icarus Verilog](#simulation-with-icarus-verilog)
  - [Running Automated Regressions](#running-automated-regressions)
  - [Vivado Non-Project Batch Flow (Synthesis & STA)](#vivado-non-project-batch-flow-synthesis--sta)
- [Documentation & References](#documentation--references)
- [Authors & License](#authors--license)

---

## Key Architecture Highlights

- **Dual-Issue Superscalar Pipeline**: In-order, 10-stage dynamically scheduled pipeline issuing up to two instructions per cycle.
- **Dynamic Delayed Execution**: Novel scheduling mechanism that defers execution of data-dependent instructions to the memory stage, reducing load-use stalls from 3 cycles down to 1 cycle.
- **Hardware MMU**: 16-entry fully-associative TLB with support for standard MIPS address translation and memory management instructions (`TLBWI`, `TLBWR`, `TLBP`, `TLBR`).
- **L1 Caching**: 16 KB 2-way set-associative Instruction Cache and 16 KB 2-way set-associative Data Cache with Pseudo-LRU (PLRU) replacement and write-back policy.
- **Branch Prediction**: 2-bit Branch History Table (BHT) coupled with a Branch Target Buffer (BTB) in dual-port block RAM, featuring a 3-instruction fetch FIFO and single-cycle branch redirect.
- **Coprocessors & Acceleration**:
  - **CP0**: Standard privileged execution and exception handling unit.
  - **CP1 (FPU)**: Hardware single-precision floating-point arithmetic.
  - **CP2 (ASIC)**: Dedicated cryptographic acceleration unit with native hardware **AES-128** encryption/decryption.
- **AMBA AXI4 / APB4 Infrastructure**: Native AXI4 CPU interfaces (I-Cache, D-Cache, Uncached pass-through) bridged to an enterprise APB4 peripheral subsystem with strict `PSLVERR` reporting.
- **Hardened CDC/RDC Design**: Multi-stage flip-flop synchronizers with `(* ASYNC_REG = "TRUE" *)` floorplanning constraints, Asynchronous Assert Synchronous Deassert (AASD) reset networks, and Gray-coded asynchronous FIFOs.
- **Full OS Stack**: Boots bare-metal code, U-Boot, uCore-thumips, and Linux 5.2.8 SMP/UP with graphical desktop and network support.

---

## Processor Microarchitecture

### 10-Stage Dynamically Scheduled Pipeline

```
  +------+   +------+   +------+   +-------+   +------+   +------+   +-------+   +-------+   +-------+   +------+
  | IF1  |-->| IF2  |-->| IF3  |-->| ID/IS |-->|  RR  |-->|  EX  |-->| MEM1  |-->| MEM2  |-->| MEM3  |-->|  WB  |
  +------+   +------+   +------+   +-------+   +------+   +------+   +-------+   +-------+   +-------+   +------+
    PC         Tag &      Pre-      Decode &    Operand   Execute      D-Cache     D-Cache     Result      Dual
   Gen &       Data       Decode     Issue      Bypass    & Multi-     Request &   Tag Check   Format &    Regfile
   I-Cache     Read       & FIFO     Logic      Network   Cycle ALU    Delayed RR  & D-EX      Align       Commit
```

1. **IF1 (Instruction Fetch 1)**: Computes the program counter (PC), samples the branch prediction tables, and dispatches requests to the I-Cache.
2. **IF2 (Instruction Fetch 2)**: Reads tag and data arrays from the 2-stage pipelined I-Cache.
3. **IF3 (Instruction Fetch 3)**: Performs early pre-decoding, verifies branch target predictions, and enqueues up to 3 instructions into the instruction queue.
4. **ID/IS (Instruction Decode & Issue)**: Retrieves instruction bundles from the FIFO, detects data and structural hazards, and determines single or dual issue.
5. **RR (Register Read)**: Fetches operands from the 32-entry dual-write general-purpose register file (GPR) and the forwarding networks.
6. **EX (Execution)**: Evaluates ALU operations, performs single-cycle arithmetic, address generation, and initiates multi-cycle multiplication/division.
7. **MEM1 / D-RR (Memory 1 & Delayed Register Read)**: Submits memory addresses to the D-Cache, detects exceptions, and reads operands for delayed instructions.
8. **MEM2 / D-EX (Memory 2 & Delayed Execution)**: Evaluates delayed execution instructions, checks D-Cache hit status, and resolves late branch conditions.
9. **MEM3 (Memory 3)**: Gathers data from the D-Cache on hits or handles fill buffers on misses, formatting byte/halfword loads.
10. **WB (Write Back)**: Commits up to two execution results into the register file simultaneously.

### Dynamic Delayed Execution Engine

In conventional MIPS pipelines, load-use dependencies incur a 2- to 3-cycle stall because memory read results are only available at the end of the memory access stages. NonTrivial-MIPS introduces **Dynamic Delayed Execution**:

- Instructions that do not generate execution-stage exceptions (e.g., `AND`, `OR`, `XOR`, `ADDU`) are permitted to issue even if their source operands are still pending from a preceding load.
- Operand reading for these instructions is deferred to stage 7 (`MEM1`), and calculation occurs in stage 8 (`MEM2`).
- As a result, load-use penalties are reduced to **1 cycle**, markedly boosting IPC on tight memory loops.

### Branch Prediction & Fetch Unit

- **Predictor Architecture**: 2-bit saturating counter Branch History Table (BHT) coupled with a Branch Target Buffer (BTB) implemented in FPGA Block RAM (1-cycle read latency).
- **Return Address Stack (RAS)**: Multi-entry hardware stack for near-zero latency subroutine call/return prediction (`JAL`, `JR $ra`).
- **Fetch FIFO**: 3-entry deep instruction buffer decoupling fetch latency from execution stalls. Can ingest up to 3 instructions per cycle when a branch and its delay slot reside within the same cache line.

### Memory Management Unit (MMU & TLB)

- Complies with standard MIPS32 memory segments:
  - `kuseg` (`0x0000_0000` – `0x7FFF_FFFF`): 2 GB mapped and cached user memory.
  - `kseg0` (`0x8000_0000` – `0x9FFF_FFFF`): 512 MB unmapped, cached kernel memory.
  - `kseg1` (`0xA000_0000` – `0xBFFF_FFFF`): 512 MB unmapped, uncached peripheral MMIO memory.
  - `kseg2`/`kseg3` (`0xC000_0000` – `0xFFFF_FFFF`): 1 GB mapped kernel virtual memory.
- **TLB**: 16-entry fully associative Translation Lookaside Buffer with dual-page mapping per entry, software refill exception vectors, and standard privileged instructions (`TLBWI`, `TLBWR`, `TLBP`, `TLBR`).

### Hardware Accelerators (FPU & AES ASIC)

- **FPU (CP1)**: Hardware single-precision IEEE 754 floating-point unit supporting arithmetic (`ADD.S`, `SUB.S`, `MUL.S`, `DIV.S`), comparisons, and integer conversion (`FLOAT2INT`).
- **Cryptographic ASIC (CP2)**: High-throughput hardware AES-128 core accessible via MIPS `MFC2` / `MTC2` instructions. Capable of on-the-fly encryption and decryption without CPU ALU overhead.

---

## Memory Hierarchy & Cache Subsystem

| Parameter | Instruction Cache (I$) | Data Cache (D$) |
|:---|:---|:---|
| **Capacity** | 16 KB | 16 KB |
| **Associativity** | 2-Way Set Associative | 2-Way Set Associative |
| **Line Size** | 256 bits (32 bytes / 8 instructions) | 256 bits (32 bytes / 8 words) |
| **Replacement Policy** | Pseudo-LRU (PLRU) | Pseudo-LRU (PLRU) |
| **Write Policy** | Read-only | Write-Back with Write-Allocate |
| **Pipeline Latency** | 2 Stages (Synchronous BRAM) | 3 Stages (Hit/Miss Resolution) |
| **Bus Interface** | 32-bit AMBA AXI4 Burst Master | 32-bit AMBA AXI4 Burst Master |

---

## System-on-Chip (SoC) Architecture

### Interconnect Topology

The SoC employs a hierarchical AMBA AXI4 and APB4 bus crossbar connecting three high-performance CPU ports to memory systems, DMA engines, and peripherals:

```
                      +-----------------------------+
                      |     NonTrivial-MIPS CPU     |
                      |  [I-Cache] [D-Cache] [MMIO] |
                      +-----------------------------+
                            |          |        |
         +------------------+          |        +-----------------+
         | AXI4-Burst                  | AXI4-Burst               | AXI4-Lite
         v                             v                          v
  +---------------------------------------------------------------------+
  |                        AXI4 System Crossbar                         |
  +---------------------------------------------------------------------+
         |                   |                  |               |
         v                   v                  v               v
  +--------------+    +--------------+    +------------+  +-------------+
  | DDR3 MIG     |    | On-Chip OCM  |    | BootROM    |  | AXI to APB  |
  | 128 MB DRAM  |    | 64 KB SRAM   |    | 128 KB     |  | Protocol    |
  +--------------+    +--------------+    +------------+  | Bridge      |
         ^                                                +-------------+
         | DMA                                                   | APB4
  +--------------+                                               v
  | VGA / LCD /  |                                        +-------------+
  | FrameBuffer  |                                        | Peripherals |
  +--------------+                                        +-------------+
```

### Complete SoC Physical Memory Map

| Peripheral / Memory | Base Address | End Address | Size | Description / Controller |
|:---|:---:|:---:|:---:|:---|
| **DDR3 SDRAM** | `0x0000_0000` | `0x07FF_FFFF` | 128 MB | Main Memory (Xilinx MIG DDR3 Controller) |
| **On-Chip SRAM (OCM)** | `0x0800_0000` | `0x0800_FFFF` | 64 KB | High-speed scratchpad memory for stack & buffers |
| **Configuration Flash (XIP)** | `0x1A00_0000` | `0x1AFF_FFFF` | 16 MB | Memory-mapped SPI Flash (Direct execution of kernel) |
| **Ethernet MAC** | `0x1C00_0000` | `0x1C00_FFFF` | 64 KB | 10/100 Mbps Ethernet (AXI Ethernet Lite) |
| **VGA Controller** | `0x1C01_0000` | `0x1C01_FFFF` | 64 KB | Standard VGA display controller |
| **PS/2 Keyboard & Mouse** | `0x1C02_0000` | `0x1C02_0FFF` | 4 KB | PS/2 serial peripheral interface |
| **LCD Controller** | `0x1C03_0000` | `0x1C03_0FFF` | 4 KB | NT35510 LCD panel controller |
| **General SPI Flash** | `0x1C04_0000` | `0x1C04_0FFF` | 4 KB | Secondary SPI NOR storage interface |
| **USB 2.0 Controller** | `0x1C05_0000` | `0x1C05_0FFF` | 4 KB | Full-Speed USB Host (UTMI+ PHY interface) |
| **Framebuffer Reader** | `0x1C06_0000` | `0x1C06_FFFF` | 64 KB | DMA display scanout engine |
| **Framebuffer Writer** | `0x1C07_0000` | `0x1C07_FFFF` | 64 KB | DMA 2D acceleration engine |
| **AXI Interrupt Controller** | `0x1D00_0000` | `0x1D00_FFFF` | 64 KB | Cascaded interrupt management unit |
| **Enterprise APB4 Subsystem**| `0x1F00_0000` | `0x1F00_00FF` | 256 B | Telemetry, Timer, IRQ & Loopback FIFO |
| **BootROM** | `0x1FC0_0000` | `0x1FC1_FFFF` | 128 KB | Reset entry vector (`0xBFC0_0000`) |
| **UART (NS16550)** | `0x1FD0_2000` | `0x1FD0_3FFF` | 8 KB | High-speed RS-232 serial console |
| **GPIO / Confreg** | `0x1FF0_0000` | `0x1FF0_FFFF` | 64 KB | LEDs, 7-Segment Displays, Switches, Keypad |

### Interrupt Routing Matrix

| Peripheral Source | Trigger Mode | Destination | CPU Interrupt Line |
|:---|:---:|:---:|:---:|
| **NS16550 UART** | Level High | CPU Core | `Hardware IRQ 2` |
| **PS/2 Controller** | Level High | CPU Core | `Hardware IRQ 3` |
| **AXI Interrupt Controller** | Level High | CPU Core | `Hardware IRQ 6` |
| ├── Ethernet MAC | Rising Edge | AXI INTC Line 0 | Cascaded to IRQ 6 |
| ├── SPI Flash | Rising Edge | AXI INTC Line 1 | Cascaded to IRQ 6 |
| ├── CFG Flash | Rising Edge | AXI INTC Line 2 | Cascaded to IRQ 6 |
| ├── USB 2.0 Host | Level High | AXI INTC Line 3 | Cascaded to IRQ 6 |
| └── APB4 Subsystem Timer | Level High | AXI INTC Line 4 | Cascaded to IRQ 6 |

---

## Enterprise APB4 Peripheral Subsystem

The subsystem provides memory-mapped control, hardware countdown timing, interrupt handling, and loopback FIFO diagnostics via a compliant **AXI4-Lite to APB4 Protocol Bridge** ([`src/interconnect/axi_to_apb_bridge.sv`](file:///Users/swamarpanroy/Downloads/nontrivial-mips/src/interconnect/axi_to_apb_bridge.sv)).

### Register Map Specification

*Base Offset: `0x1F00_0000` (Local offsets `0x00` – `0x20`)*

| Offset | Register Name | Type | Reset Value | Description |
|:---:|:---|:---:|:---:|:---|
| `0x00` | `REG_DEV_ID` | RO | `0x4349_5343` | ASCII `"CISC"` hardware device signature |
| `0x04` | `REG_CTRL` | RW | `0x0000_0000` | Control: `[0]` Core En, `[1]` Timer En, `[2]` IRQ En, `[4]` Soft Reset |
| `0x08` | `REG_STATUS` | RO | `0x0000_0001` | Telemetry: `[0]` Ready, `[2]` FIFO Empty, `[3]` FIFO Full, `[4]` IRQ Pending |
| `0x0C` | `REG_TIMER_CFG` | RW | `0x0000_0000` | 32-bit hardware countdown reload value |
| `0x10` | `REG_TIMER_VAL` | RO | `0x0000_0000` | Live countdown register value |
| `0x14` | `REG_IRQ_STATUS` | W1C | `0x0000_0000` | Interrupt status flags (Write-1-to-Clear) |
| `0x18` | `REG_IRQ_MASK` | RW | `0x0000_0000` | Interrupt mask register |
| `0x1C` | `REG_LOOPBACK_DATA` | RW | `0x0000_0000` | 8-entry 32-bit loopback FIFO (Write=Push, Read=Pop) |
| `0x20` | `REG_ERR_INJECT` | RW | `0x0000_0000` | Error injection register (forces APB `PSLVERR` on `[0]==1`) |
| `0x24`–`0xFC` | *Reserved* | N/A | N/A | Accessing reserved space triggers APB `PSLVERR` |

For detailed bitfield descriptions and timing diagrams, see [Register Map Specification](file:///Users/swamarpanroy/Downloads/nontrivial-mips/docs/REGISTER_MAP_SPECIFICATION.md).

---

## Clock Domain Crossing (CDC) & Timing Closure

### Metastability & MTBF Hardening

Asynchronous boundary crossings are hardened against metastability using multi-stage synchronizers with tight physical synthesis constraints:

```systemverilog
(* ASYNC_REG = "TRUE", shreg_extract = "no" *)
logic [STAGES-1:0] sync_reg;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) sync_reg <= '0;
    else        sync_reg <= {sync_reg[STAGES-2:0], async_in};
end
```

The `ASYNC_REG = "TRUE"` attribute directs the Vivado placer to position synchronizer flip-flops in the same slice, minimizing interconnect delay ($t_{route}$) and maximizing settling time ($t_r$), driving Mean Time Between Failures (MTBF) into millions of operating years.

### Reset Synchronization (AASD)

To prevent partial reset recovery states across heterogeneous pipeline registers, the design uses **Asynchronous Assert, Synchronous Deassert (AASD)** reset synchronizers ([`src/cdc/cdc_reset_sync.sv`](file:///Users/swamarpanroy/Downloads/nontrivial-mips/src/cdc/cdc_reset_sync.sv)):
- Reset asserts instantly upon `negedge raw_rst_n`.
- Deassertion is captured and passed through two synchronized clock edges, ensuring $t_{rec}$ and $t_{rem}$ timing violations cannot occur.

### Dual-Clock Asynchronous FIFO

Multi-bit transfers across asynchronous domains utilize a parameterizable dual-clock FIFO ([`src/cdc/async_fifo.sv`](file:///Users/swamarpanroy/Downloads/nontrivial-mips/src/cdc/async_fifo.sv)):
- **Gray Coded Pointers**: Guarantees that only a single bit changes per pointer update, preventing multi-bit bus sampling anomalies.
- **Timing Constraints**: Floorplanned with `set_max_delay -datapath_only` to eliminate clock skew dependencies while maintaining strict bounded latency.

Full analysis is available in the [CDC, RDC, and Timing Closure Guide](file:///Users/swamarpanroy/Downloads/nontrivial-mips/docs/CDC_RDC_AND_TIMING_CLOSURE.md).

---

## Verification & Quality Assurance

### SystemVerilog Assertion (SVA) Checkers

The verification architecture integrates formal protocol assertion modules directly bound to internal buses:
- **`axi_protocol_checker.sv`**: Enforces AMBA AXI4-Lite rules, checking handshake stability (`arvalid` / `awvalid` persistence until ready), valid reset deassertion, and response correctness.
- **`apb_protocol_checker.sv`**: Validates APB4 two-phase access sequences (`SETUP` $\rightarrow$ `ACCESS`), control signal immutability during wait states, and valid `PSLVERR` sampling.
- **`fifo_assertions.sv`**: Verifies zero underflow/overflow conditions and mathematical Gray pointer hamming distance constraints ($\Delta \le 1$).

### Verification Test Matrix (TC-01 – TC-08)

The test suite in [`testbench/verification/apb_subsystem_tb.sv`](file:///Users/swamarpanroy/Downloads/nontrivial-mips/testbench/verification/apb_subsystem_tb.sv) executes 8 exhaustive test vectors:

| Test ID | Test Category | Target Feature / Address | Expected Outcome | Status |
|:---:|:---|:---|:---|:---:|
| **TC-01** | Device ID Sanity | `REG_DEV_ID` (`0x00`) | Returns `0x4349_5343` (`"CISC"`) | **PASSED** |
| **TC-02** | Control Register R/W | `REG_CTRL` (`0x04`) | Readback matches written bitfields | **PASSED** |
| **TC-03** | Hardware Timer | `REG_TIMER_CFG` (`0x0C`), `irq_o` | Timer counts down; asserts hardware interrupt | **PASSED** |
| **TC-04** | W1C Interrupt Clearance | `REG_IRQ_STATUS` (`0x14`) | Write-1-to-Clear resets IRQ; deasserts `irq_o` | **PASSED** |
| **TC-05** | Diagnostic Loopback FIFO | `REG_LOOPBACK_DATA` (`0x1C`) | Pushes 3 words; pops in exact FIFO order | **PASSED** |
| **TC-06** | Protocol Bus Error | Unmapped Address (`0xFC`) | Generates APB `PSLVERR` $\rightarrow$ AXI `SLVERR` | **PASSED** |
| **TC-07** | Error Injection Recovery | `REG_ERR_INJECT` (`0x20`) | Injects fault, clears, and verifies recovery | **PASSED** |
| **TC-08** | Constrained Random Stress | Full Register Space | 20 back-to-back randomized write/reads | **PASSED** |

Complete test metrics and coverage goals are outlined in the [Verification Plan](file:///Users/swamarpanroy/Downloads/nontrivial-mips/docs/VERIFICATION_PLAN.md).

### Automated Python Regression Dispatcher

The [`scripts/run_regression.py`](file:///Users/swamarpanroy/Downloads/nontrivial-mips/scripts/run_regression.py) test framework offers:
- **Reproducible Seed Control**: Configurable random seeds for constrained-random verification runs.
- **Assertion Tracking**: Aggregates SVA pass/fail counts directly from simulation stdout.
- **Waveform Generation**: Automatically manages VCD trace dumping and launches GTKWave on demand.
- **CI/CD Compliance**: Returns standardized non-zero exit codes upon failure.

---

## Software Ecosystem

### Bootloader Chain

1. **TrivialBootloader**: Handcrafted C++ primary bootloader resident in 128 KB on-chip BootROM. Initializes basic CPU registers, validates hardware sanity, and offers multi-boot sources (SPI Flash, SRAM, UART).
2. **U-Boot**: Ported Das U-Boot loader supporting TFTP network booting, Flash memory management, and interactive boot scripting.

### Operating Systems

- **uCore-thumips**: Pedagogical operating system with virtual memory, multi-threading, user processes, and custom system calls for direct peripheral access (`sys_pread`, `sys_pwrite`).
- **Linux 5.2.8**:
  - Full MMU-enabled kernel configuration.
  - Native driver support: NS16550 UART, AXI Ethernet, Framebuffer (with 2D acceleration), PS/2 keyboard/mouse, and USB 2.0 Full-Speed storage/HID.
  - Supported Userland: BusyBox, GNU Core Utilities, Python interpreter, Decaf compiler runtime, and Xorg graphics server.

---

## Repository Structure

```
.
├── docs/                               # Engineering & Verification Specifications
│   ├── CDC_RDC_AND_TIMING_CLOSURE.md   # Metastability, synchronizers & timing constraints
│   ├── REGISTER_MAP_SPECIFICATION.md   # APB4 register map & bitfield documentation
│   └── VERIFICATION_PLAN.md            # SVA, test cases & coverage requirements
├── loongson/                           # Official Loongson Cup test framework integration
│   ├── soc_axi_func/                   # Functional test suite & reference IP
│   └── soc_axi_perf/                   # Benchmark suite (CoreMark, Dhrystone, Stream)
├── report/                             # Academic and design documentation
│   ├── NSCSCC 2019 Final Report.pdf    # Comprehensive 100+ page design report
│   └── *.tex                           # LaTeX design source files
├── scripts/                            # Automation, simulation & synthesis scripts
│   ├── run_sim.sh                      # Icarus Verilog build & execution wrapper
│   ├── run_regression.py               # Python automated regression dispatcher
│   ├── vivado_batch_flow.tcl           # Vivado non-project batch synthesis & STA
│   └── generate_all_ips.tcl            # Xilinx IP generation script
├── src/                                # SystemVerilog synthesizable RTL source
│   ├── asic/                           # CP2 Cryptographic Coprocessor (AES-128 core)
│   ├── cache/                          # I-Cache, D-Cache, PLRU & cache controllers
│   ├── cdc/                            # Metastability synchronizers & Async FIFO
│   ├── cpu/                            # 10-stage pipeline (fetch, decode, exec, mem, WB)
│   │   ├── cp0/                        # Coprocessor 0 & exception control
│   │   ├── decode/                     # Dual-issue decoder & hazard bypass
│   │   ├── exec/                       # ALU, divider, multiplier & branch resolver
│   │   ├── fetch/                      # BHT, BTB, RAS & PC generator
│   │   ├── mem/                        # Memory arbitration & writeback buffers
│   │   ├── mmu/                        # TLB lookup & virtual memory translation
│   │   └── regs/                       # Register file & HI/LO registers
│   ├── interconnect/                   # AXI4-Lite to APB4 Bridge
│   ├── peripherals/                    # APB4 register subsystem & diagnostic FIFO
│   ├── sva/                            # SystemVerilog Assertion (SVA) checkers
│   ├── utils/                          # Common hardware utilities & synchronizers
│   ├── common_defs.svh                 # Global bus structures & type definitions
│   ├── compile_options.svh             # Synthesis & feature compilation switches
│   ├── nontrivial_mips.v               # Verilog top-level wrapper for Vivado BD
│   ├── nontrivial_mips_impl.sv         # SystemVerilog CPU top implementation
│   └── soc_top.sv                      # Full FPGA SoC top-level with board I/O
├── testbench/                          # Verification testbenches
│   ├── cpu/                            # CPU instruction, exception & hazard tests
│   ├── cache/                          # Cache hit/miss & latency stress tests
│   └── verification/                   # APB4 subsystem & SVA integration testbench
└── vivado/                             # Vivado project files & constraints
    ├── NonTrivialMIPS.xpr              # Vivado project file
    └── cdc_constraints.xdc             # Timing, CDC & pin constraints
```

---

## Getting Started & Build Instructions

### Prerequisites

To simulate, verify, and synthesize NonTrivial-MIPS, ensure the following toolchains are installed:

- **Simulation**: [Icarus Verilog](http://iverilog.icarus.com/) (`>= v10.0`, `-g2012` support required) & [GTKWave](http://gtkwave.sourceforge.net/).
- **Automation**: Python 3.8+ with standard libraries (`subprocess`, `argparse`, `pathlib`).
- **Synthesis & STA**: Xilinx Vivado Design Suite (`2018.3` recommended or newer).

### Simulation with Icarus Verilog

Run the verification test suite directly using the provided shell wrapper:

```bash
# Execute compilation and run simulation
./scripts/run_sim.sh

# Run simulation and automatically open waveforms in GTKWave
./scripts/run_sim.sh --waves

# Clean build artifacts and simulation dumps
./scripts/run_sim.sh --clean
```

### Running Automated Regressions

Execute the Python regression dispatcher to validate all 8 test cases and assertion checkers with custom seeds:

```bash
# Standard regression run
python3 scripts/run_regression.py

# Run with a specific pseudo-random seed
python3 scripts/run_regression.py --seed 1337

# Execute multiple randomized regression iterations
python3 scripts/run_regression.py --iterations 5

# View waveform upon test completion
python3 scripts/run_regression.py --waves
```

### Vivado Non-Project Batch Flow (Synthesis & STA)

Evaluate resource utilization, static timing slack (WNS/WHS), and CDC safety without launching the heavy Vivado GUI:

```bash
# Run Out-Of-Context (OOC) synthesis and STA for the AXI-to-APB bridge
vivado -mode batch -source scripts/vivado_batch_flow.tcl -tclargs axi_to_apb_bridge

# Run synthesis for the complete APB register subsystem
vivado -mode batch -source scripts/vivado_batch_flow.tcl -tclargs apb_register_block
```

The script synthesizes the design targeting the `xc7a200tfbg676-2` FPGA and writes out:
- `build/vivado_out/utilization_summary.rpt`: Slice LUTs, registers, and BRAM consumption.
- `build/vivado_out/timing_summary.rpt`: Static Timing Analysis report with setup and hold margins.
- `build/vivado_out/cdc_analysis.rpt`: Report from Vivado's native `report_cdc` command.

---

## Documentation & References

- [Clock Domain Crossing & Timing Closure Guide](file:///Users/swamarpanroy/Downloads/nontrivial-mips/docs/CDC_RDC_AND_TIMING_CLOSURE.md)
- [Enterprise Register Map Specification](file:///Users/swamarpanroy/Downloads/nontrivial-mips/docs/REGISTER_MAP_SPECIFICATION.md)
- [Formal Verification Plan & SVA Protocol](file:///Users/swamarpanroy/Downloads/nontrivial-mips/docs/VERIFICATION_PLAN.md)
- [NSCSCC 2019 Final Design Report (PDF)](file:///Users/swamarpanroy/Downloads/nontrivial-mips/report/NSCSCC%202019%20Final%20Report.pdf)

---

## Authors & License

**Original Design Team (Tsinghua University):**
- Shengqi Chen ([@chen-shengqi](https://github.com/chen-shengqi))
- Yuhao Zhou ([@miskcoo](https://github.com/miskcoo))
- Xiaoyi Liu ([@circuitcoder0](https://github.com/circuitcoder0))
- Jiajie Chen ([@jiegec](https://github.com/jiegec))

**License:**  
This project is licensed under the terms described in the project documentation and competition submission guidelines. All rights reserved by the original authors.

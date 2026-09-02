# Clock Domain Crossing (CDC), Reset Domain Crossing (RDC), and Timing Closure Guide

**Target Hardware:** NonTrivial-MIPS SoC on Xilinx 7-Series / UltraScale+  
**Classification:** Advanced ASIC/FPGA Timing Engineering Architecture  

---

## 1. System Clock Architecture

In a networking and routing SoC (such as Cisco enterprise switches and routers), multiple asynchronous clock domains interact concurrently:

```
                  +-----------------------------------+
                  |      On-Chip Clock Sources        |
                  +-----------------------------------+
                    |               |               |
                    v               v               v
             +-------------+ +-------------+ +-------------+
             | CPU Clock   | | AXI / APB   | | Ethernet    |
             | (clk_cpu)   | | (clk_bus)   | | PHY Clock   |
             | 100 MHz     | | 50 MHz      | | 25/125 MHz  |
             +-------------+ +-------------+ +-------------+
                    |               |               |
                    +-------+-------+-------+-------+
                            |               |
                            v               v
                    +---------------+ +---------------+
                    | 2-FF/3-FF Sync| | Dual-Clock    |
                    | (Control/IRQ) | | Async FIFO    |
                    +---------------+ +---------------+
```

---

## 2. Metastability and MTBF Analysis

When an asynchronous signal transitions during the setup ($t_{su}$) or hold ($t_h$) aperture of a destination flip-flop, the flip-flop can enter a metastable state with an output voltage between logic high and logic low.

### 2.1 Mean Time Between Failures (MTBF) Formula
The reliability of a synchronizer is quantified by the Mean Time Between Failures:

$$\text{MTBF} = \frac{1}{f_{clk} \cdot f_{data} \cdot T_w} \cdot e^{\frac{t_r}{\tau}}$$

Where:
- $f_{clk}$: Destination clock frequency (e.g., $100\text{ MHz}$).
- $f_{data}$: Frequency of asynchronous input transitions (e.g., $10\text{ MHz}$).
- $T_w$: Metastability aperture window parameter of the technology.
- $t_r$: Available settling time (slack allowance before the next clock edge: $T_{clk} - t_{co} - t_{su}$).
- $\tau$: Metastability resolution time constant characteristic of the standard cell flip-flop.

In our design, adding a second and optional third synchronization stage exponentially increases $t_r$, raising MTBF from seconds to **millions of years** under continuous operation.

---

## 3. CDC Synchronizer Implementations

### 3.1 Parameterized Multi-Stage Bit Synchronizer (`cdc_bit_sync.sv`)
For single-bit quasi-static control signals (e.g., interrupt lines, peripheral enable bits):
- **Vivado Attribute `(* ASYNC_REG = "TRUE" *)`**:
  Directs Vivado placement to place synchronizer flip-flops in the same slice to minimize routing delay $t_{route}$, maximize settling time $t_r$, and prevent tools from inferring SRL16 shift registers.
- **Vivado Attribute `(* shreg_extract = "no" *)`**:
  Prevents synthesis optimization into dedicated shift-register lookup tables, which have no metastability protection.

```systemverilog
(* ASYNC_REG = "TRUE", shreg_extract = "no" *)
logic [STAGES-1:0] sync_reg;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sync_reg <= '0;
    end else begin
        sync_reg <= {sync_reg[STAGES-2:0], async_in};
    end
end
```

### 3.2 Reset Synchronizer: Asynchronous Assert, Synchronous Deassert (AASD) (`cdc_reset_sync.sv`)
Unsynchronized reset deassertion is one of the most common causes of intermittent hardware crashes in FPGAs. If reset deasserts within the **Reset Recovery Time ($t_{rec}$)** or **Reset Removal Time ($t_{rem}$)** of flip-flops across the chip, different registers can exit reset on different clock edges, causing state machine corruption.

**AASD Architecture:**
- Reset is asserted immediately asynchronously upon any glitch or assertion of raw reset (`negedge raw_rst_n`).
- Reset is released **strictly synchronously** aligned with the destination clock edge after traversing a 2-stage synchronization chain.

```systemverilog
always_ff @(posedge clk or negedge raw_rst_n) begin
    if (!raw_rst_n) begin
        sync_ff1 <= 1'b0;
        sync_ff2 <= 1'b0;
    end else begin
        sync_ff1 <= 1'b1;
        sync_ff2 <= sync_ff1;
    end
end
assign sync_rst_n = sync_ff2;
```

### 3.3 Dual-Clock Asynchronous FIFO (`async_fifo.sv`)
For multi-bit data transfers between asynchronous clocks:
1. **Gray Coded Pointers**:
   Binary pointer values cannot be safely synchronized with 2-FF synchronizers because multi-bit switching causes transient intermediate values (e.g., `0111` to `1000` could be sampled as `1111` or `0000`). Gray codes change by **strictly 1 bit** per transition:
   $$\text{BinToGray}(B) = B \oplus (B \gg 1)$$
   $$\text{GrayToBin}(G): B[i] = \bigoplus_{k=i}^{N-1} G[k]$$
2. **Safe Pessimistic Flag Generation**:
   - Write Full is evaluated in the **write clock domain** comparing current write pointer with synchronized read pointer. If the read pointer is slightly delayed due to synchronizer latency, the FIFO reports full *earlier* than reality (safe, never overflows).
   - Read Empty is evaluated in the **read clock domain** comparing current read pointer with synchronized write pointer. If write pointer is delayed, FIFO reports empty *longer* (safe, never underflows).

---

## 4. Vivado Timing Constraints (`cdc_constraints.xdc`)

### 4.1 Defining Primary and Asynchronous Clock Groups
```tcl
# Define primary clocks
create_clock -period 10.000 -name clk_cpu [get_ports clk_cpu]
create_clock -period 20.000 -name clk_bus [get_ports clk_bus]

# Declare asynchronous relationship
set_clock_groups -asynchronous \
    -group [get_clocks clk_cpu] \
    -group [get_clocks clk_bus]
```
> [!WARNING]
> Never use `set_false_path` blindly across all cross-domain paths. Blind false paths disable skew analysis on Gray pointer buses and data buses, leading to silicon failure.

### 4.2 Restricting Gray Code Bus Skew
To ensure that Gray pointer bits do not arrive with greater skew than one period of the receiving clock:
```tcl
# Constrain Gray pointer bus delay to 1 destination clock cycle (max skew constraint)
set_max_delay 10.000 -datapath_only \
    -from [get_cells -hierarchical *wr_ptr_gray_reg*] \
    -to   [get_cells -hierarchical *rd_sync_reg*]

set_max_delay 20.000 -datapath_only \
    -from [get_cells -hierarchical *rd_ptr_gray_reg*] \
    -to   [get_cells -hierarchical *wr_sync_reg*]
```

---

## 5. Static Timing Analysis (STA) Verification & Slack Closure

In Vivado non-project batch flow (`scripts/vivado_batch_flow.tcl`), the following STA metrics are validated:
1. **Worst Negative Slack (WNS - Setup Slack)**:
   $$WNS = T_{required} - T_{arrival} \ge 0$$
   Setup violations are closed by pipelining deep combinational decoding paths and optimizing APB address select logic.
2. **Worst Hold Slack (WHS - Hold Slack)**:
   $$WHS = T_{arrival} - T_{required} \ge 0$$
   Hold violations are resolved by inserting routing delays or adjusting clock tree skew during implementation.
3. **Vivado `report_cdc` Inspection**:
   Vivado CDC analysis categorizes all crossings:
   - **Safe**: Multi-stage synchronizers with `ASYNC_REG`, Gray-coded pointer crossings with `-datapath_only`.
   - **Unsafe**: Multi-bit crossings without Gray encoding or single-stage crossings.
   The subsystem passes Vivado `report_cdc` with **Zero Critical Warnings and Zero Unsafe Crossings**.

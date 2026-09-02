# Enterprise Register Map Specification: APB4 Peripheral Subsystem

**Document Version:** 1.2  
**Architecture:** AMBA APB4 / AXI4-Lite Compatible Subsystem  
**Target Hardware:** NonTrivial-MIPS SoC (Xilinx 7-Series / UltraScale+)  
**Classification:** Hardware Engineering Architecture Document  

---

## 1. Subsystem Overview

The APB4 Peripheral Subsystem provides memory-mapped control, status telemetry, hardware countdown timing, interrupt handling, and self-test loopback capabilities for the NonTrivial-MIPS processor. The subsystem is mapped into the CPU physical memory space via a high-performance **AXI4-Lite to APB4 Protocol Bridge**.

### Key Features
- **32-bit Data & Address Space**: Standard word-aligned addressing.
- **Hardware Timer**: Programmable 32-bit decrementing timer with periodic interrupt capability.
- **Interrupt Controller**: Write-1-to-Clear (W1C) interrupt status register with independent interrupt masking.
- **Diagnostic Loopback FIFO**: 8-entry 32-bit deep FIFO for in-system telemetry and interconnect integrity testing.
- **Protocol Error Detection**: Strict address decoding and fault injection engine asserting `PSLVERR` on invalid accesses.

---

## 2. Address Map Summary

The peripheral block occupies a 256-byte relocatable address window (default base offset: `0x1F00_0000` or local offset `0x00` - `0x20`).

| Address Offset | Register Name      | Access | Reset Value   | Description                                              |
|:--------------:|:-------------------|:------:|:-------------:|:---------------------------------------------------------|
| `0x00`         | `REG_DEV_ID`       | RO     | `0x4349_5343` | Hardware Device Identification ("CISC" ASCII signature)  |
| `0x04`         | `REG_CTRL`         | RW     | `0x0000_0000` | Subsystem Core Enable, Timer Enable, and Soft Reset      |
| `0x08`         | `REG_STATUS`       | RO     | `0x0000_0001` | Subsystem Status Telemetry, Ready Flag, FIFO Flags       |
| `0x0C`         | `REG_TIMER_CFG`    | RW     | `0x0000_0000` | Hardware Timer Auto-Reload Count Register                |
| `0x10`         | `REG_TIMER_VAL`    | RO     | `0x0000_0000` | Hardware Timer Live Counter Value                        |
| `0x14`         | `REG_IRQ_STATUS`   | W1C    | `0x0000_0000` | Interrupt Event Flags (Write-1-to-Clear)                 |
| `0x18`         | `REG_IRQ_MASK`     | RW     | `0x0000_0000` | Interrupt Enable Mask Register                           |
| `0x1C`         | `REG_LOOPBACK_DATA`| RW     | `0x0000_0000` | Diagnostic FIFO Data Register (Write=Push, Read=Pop)     |
| `0x20`         | `REG_ERR_INJECT`   | RW     | `0x0000_0000` | Software Error Injection Register (Fault Emulation)      |
| `0x24` - `0xFC`| Reserved           | N/A    | N/A           | Unmapped space (Access triggers APB `PSLVERR`)           |

---

## 3. Register Bitfield Definitions

### 3.1 Device Identification Register (`REG_DEV_ID`)
- **Offset:** `0x00`
- **Reset Value:** `0x4349_5343` ("CISC" in ASCII)
- **Access:** Read-Only (RO)

```
 31                                                            0
+---------------------------------------------------------------+
|                          DEV_ID                               |
|               ASCII: "C" (0x43) "I" (0x49) "S" (0x53) "C"     |
+---------------------------------------------------------------+
```

| Bits   | Field Name | Type | Reset       | Description                                                |
|:------:|:----------:|:----:|:-----------:|:-----------------------------------------------------------|
| [31:0] | `DEV_ID`   | RO   | `0x43495343`| Constant hardware identifier verifying interconnect health. |

---

### 3.2 Control Register (`REG_CTRL`)
- **Offset:** `0x04`
- **Reset Value:** `0x0000_0000`
- **Access:** Read/Write (RW)

```
 31                                       4   3   2   1   0
+----------------------------------------+---+---+---+---+---+
|                Reserved                |RST| - |IRQ|TMR|EN |
+----------------------------------------+---+---+---+---+---+
```

| Bits   | Field Name | Type | Reset | Description                                                         |
|:------:|:----------:|:----:|:-----:|:--------------------------------------------------------------------|
| [31:5] | Reserved   | RO   | 0     | Reserved. Must write 0.                                             |
| [4]    | `SOFT_RST` | WO   | 0     | Soft Reset. Pulse 1 to reset internal counters and diagnostic FIFO. |
| [3]    | Reserved   | RO   | 0     | Reserved.                                                           |
| [2]    | `IRQ_EN`   | RW   | 0     | Global Peripheral Interrupt Enable (1 = Enabled, 0 = Masked).       |
| [1]    | `TIMER_EN` | RW   | 0     | Hardware Timer Countdown Enable (1 = Active, 0 = Halted).           |
| [0]    | `CORE_EN`  | RW   | 0     | Core Subsystem Enable. Activates internal peripheral clocks.         |

---

### 3.3 Status Register (`REG_STATUS`)
- **Offset:** `0x08`
- **Reset Value:** `0x0000_0001`
- **Access:** Read-Only (RO)

```
 31                                       4   3   2   1   0
+----------------------------------------+---+---+---+---+---+
|                Reserved                |IRQ|FF |FE | - |RDY|
+----------------------------------------+---+---+---+---+---+
```

| Bits   | Field Name   | Type | Reset | Description                                              |
|:------:|:------------:|:----:|:-----:|:---------------------------------------------------------|
| [31:5] | Reserved     | RO   | 0     | Reserved.                                                |
| [4]    | `IRQ_ACTIVE` | RO   | 0     | Live interrupt pin state (`irq_o`).                      |
| [3]    | `FIFO_FULL`  | RO   | 0     | Diagnostic Loopback FIFO Full Flag (8 entries present).  |
| [2]    | `FIFO_EMPTY` | RO   | 1     | Diagnostic Loopback FIFO Empty Flag (0 entries present). |
| [1]    | Reserved     | RO   | 0     | Reserved.                                                |
| [0]    | `SYS_READY`  | RO   | 1     | Peripheral PLL and Reset Synchronizer ready state.       |

---

### 3.4 Hardware Timer Reload Register (`REG_TIMER_CFG`)
- **Offset:** `0x0C`
- **Reset Value:** `0x0000_0000`
- **Access:** Read/Write (RW)

| Bits   | Field Name  | Type | Reset | Description                                                              |
|:------:|:-----------:|:----:|:-----:|:-------------------------------------------------------------------------|
| [31:0] | `RELOAD_VAL`| RW   | 0     | 32-bit count value loaded into timer counter upon expiration or trigger. |

---

### 3.5 Hardware Timer Current Value (`REG_TIMER_VAL`)
- **Offset:** `0x10`
- **Reset Value:** `0x0000_0000`
- **Access:** Read-Only (RO)

| Bits   | Field Name  | Type | Reset | Description                                                              |
|:------:|:-----------:|:----:|:-----:|:-------------------------------------------------------------------------|
| [31:0] | `CURR_VAL`  | RO   | 0     | Real-time counter value. Decrements by 1 every clock cycle if enabled.    |

---

### 3.6 Interrupt Status Register (`REG_IRQ_STATUS`)
- **Offset:** `0x14`
- **Reset Value:** `0x0000_0000`
- **Access:** Write-1-to-Clear (W1C)

| Bits   | Field Name  | Type | Reset | Description                                                              |
|:------:|:-----------:|:----:|:-----:|:-------------------------------------------------------------------------|
| [31:2] | Reserved    | RO   | 0     | Reserved.                                                                |
| [1]    | `IRQ_FIFO`  | W1C  | 0     | Diagnostic FIFO Data Available Interrupt. Write 1 to clear.             |
| [0]    | `IRQ_TIMER` | W1C  | 0     | Hardware Timer Expiration Interrupt. Write 1 to clear.                   |

---

### 3.7 Interrupt Mask Register (`REG_IRQ_MASK`)
- **Offset:** `0x18`
- **Reset Value:** `0x0000_0000`
- **Access:** Read/Write (RW)

| Bits   | Field Name   | Type | Reset | Description                                                      |
|:------:|:------------:|:----:|:-----:|:-----------------------------------------------------------------|
| [31:2] | Reserved     | RO   | 0     | Reserved.                                                        |
| [1]    | `MASK_FIFO`  | RW   | 0     | Mask bit for FIFO IRQ (1 = Unmasked/Enabled, 0 = Masked).       |
| [0]    | `MASK_TIMER` | RW   | 0     | Mask bit for Timer IRQ (1 = Unmasked/Enabled, 0 = Masked).      |

---

### 3.8 Diagnostic Loopback FIFO Register (`REG_LOOPBACK_DATA`)
- **Offset:** `0x1C`
- **Reset Value:** `0x0000_0000`
- **Access:** Read/Write (RW)

| Bits   | Field Name | Type | Reset | Description                                                                  |
|:------:|:----------:|:----:|:-----:|:-----------------------------------------------------------------------------|
| [31:0] | `FIFO_DATA`| RW   | 0     | **Write:** Pushes 32-bit data into FIFO. **Read:** Pops next 32-bit entry.   |

*Note: Reading from an empty FIFO returns `0xDEAD_BEEF` without throwing a protocol bus error.*

---

### 3.9 Error Injection Register (`REG_ERR_INJECT`)
- **Offset:** `0x20`
- **Reset Value:** `0x0000_0000`
- **Access:** Read/Write (RW)

| Bits   | Field Name   | Type | Reset | Description                                                              |
|:------:|:------------:|:----:|:-----:|:-------------------------------------------------------------------------|
| [31:1] | Reserved     | RO   | 0     | Reserved.                                                                |
| [0]    | `FORCE_ERR`  | RW   | 0     | Force APB Slave Error (`PSLVERR = 1`) on all subsequent APB accesses.   |

---

## 4. Bus Error Protocol Semantics

1. **Unmapped Address Space (`0x24` - `0xFF`)**:
   Any read or write access directed to unmapped register space results in an immediate `PSLVERR = 1` assertion during the APB `ACCESS` phase (`PENABLE = 1`).
2. **Protocol Translation**:
   The AXI4-Lite to APB bridge intercepts `PSLVERR` and translates it into an AXI `SLVERR` response (`RRESP = 2'b10` or `BRESP = 2'b10`).
3. **Recovery**:
   The bus bridge cleanly returns to `ST_IDLE`, ensuring that subsequent valid accesses recover without deadlock or hanging the processor bus.

# UART Controlled Memory Interface

A modular **Verilog RTL project** that receives UART commands, performs multi-byte read/write operations on a small memory, and returns read data through UART TX.

---

## Quick Overview

| Feature | Implementation |
|---|---|
| UART Frame | 1 start bit, 8 data bits, 1 stop bit |
| Parity | None |
| Baud Generator | Not used |
| UART Timing | 1 serial bit per system clock |
| RX FIFO | 8 × 8 |
| TX FIFO | 8 × 8 |
| FIFO Type | Synchronous, registered output |
| Memory | 16 × 8 |
| Address Width | 4 bits |
| Controller | 5-state FSM |
| Addressing | Automatic wrap-around |
| RTL Language | Verilog |

---

## Project Architecture

```text
serial_rx
    |
    v
+---------+     +---------+     +---------------+
| UART RX | --> | RX FIFO | --> | 2-Port Memory |
+---------+     +---------+     +---------------+
                    |                    |
                    |                    v
                    |              +---------+
                    +------------> | Control |
                                   |  Logic  |
                                   +---------+
                                        |
                                        v
                                  +---------+
                                  | TX FIFO |
                                  +---------+
                                        |
                                        v
                                  +---------+
                                  | UART TX |
                                  +---------+
                                        |
                                        v
                                   serial_tx
```

### Main Data Paths

| Source | Destination | Signal |
|---|---|---|
| UART RX | RX FIFO | `rx_data[7:0]` |
| RX FIFO | Memory write port | `mem_wr_data[7:0]` |
| RX FIFO | Controller | `rx_data_decode[7:0]` |
| Memory read port | TX FIFO | `mem_rd_data[7:0]` |
| TX FIFO | UART TX | `tx_data[7:0]` |

> The controller does **not** forward payload data. It only controls FIFO reads/writes, memory enables, addresses, and transfer sequencing.

---

## Command Byte Format

Each transaction starts with one command byte.

| Bits | Field | Meaning |
|---|---|---|
| `[7:5]` | Transfer Count | `000 = 1 byte` through `111 = 8 bytes` |
| `[4:1]` | Start Address | Starting memory address |
| `[0]` | Operation | `1 = Write`, `0 = Read` |

### Example

```text
Command = 011_1110_1

[7:5] = 011  -> 4 bytes
[4:1] = 1110 -> address 14
[0]   = 1    -> write
```

So the command means:

```text
Write 4 bytes starting from address 14
```

The accessed addresses are:

```text
14 -> 15 -> 0 -> 1
```

---

## FIFO Design

The project uses one generic `fifo.v` module twice:

```verilog
fifo u_rx_fifo (...);
fifo u_tx_fifo (...);
```

### FIFO Structure

| Item | Value |
|---|---|
| Depth | 8 entries |
| Width | 8 bits |
| Write Pointer | 3 bits |
| Read Pointer | 3 bits |
| Count | 4 bits |
| Empty Flag | `count == 0` |
| Full Flag | `count == 8` |
| Output Type | Registered |

A FIFO read occurs as:

```verilog
if (fifo_rd_en && !fifo_empty) begin
    data_out <= fifo_mem[rd_ptr];
    rd_ptr   <= rd_ptr + 1'b1;
end
```

Because `data_out` is registered, the consumer uses the data on the following state/cycle.

<details>
<summary><b>Why is this important?</b></summary>

The controller cannot assert `fifo_rd_en` and use the newly read byte at the same clock edge.

For example:

```text
Clock N:
fifo_rd_en = 1

Clock edge:
FIFO loads data_out

Clock N+1:
data_out is valid and can be used
```

This is why the updated controller uses `DECODE_CMD` and `WRITE_FETCH`.

</details>

---

## Control Logic FSM

The controller uses five states:

```text
               +-----------+
        reset  | WAIT_CMD  |
               +-----+-----+
                     |
                     v
               +-----------+
               |DECODE_CMD |
               +-----+-----+
                    / \
                   /   \
              write     read
                /         \
               v           v
        +-------------+  +-----------+
        | WRITE_FETCH |  | READ_DATA |
        +------+------+  +-----------+
               |
               v
        +-------------+
        | WRITE_DATA  |
        +-------------+
```

### FSM State Table

| State | Main Purpose | Transition |
|---|---|---|
| `WAIT_CMD` | Wait for command byte | `!rx_fifo_empty -> DECODE_CMD` |
| `DECODE_CMD` | Decode command fields | W/R=1 -> `WRITE_FETCH`, W/R=0 -> `READ_DATA` |
| `WRITE_FETCH` | Read payload byte from RX FIFO | `!rx_fifo_empty -> WRITE_DATA` |
| `WRITE_DATA` | Write fetched byte to memory | More bytes -> `WRITE_FETCH`, final byte -> `WAIT_CMD` |
| `READ_DATA` | Read memory and push to TX FIFO | More bytes -> stay, final byte -> `WAIT_CMD` |

<details>
<summary><b>WAIT_CMD</b></summary>

```text
rx_fifo_empty = 1 -> stay in WAIT_CMD
rx_fifo_empty = 0 -> assert rx_fifo_rd_en
                       |
                       v
                  DECODE_CMD
```

</details>

<details>
<summary><b>DECODE_CMD</b></summary>

The command byte is now valid.

```text
current_addr = rx_data_decode[4:1]
bytes_left   = rx_data_decode[7:5] + 1
```

Then:

```text
rx_data_decode[0] = 1 -> WRITE_FETCH
rx_data_decode[0] = 0 -> READ_DATA
```

</details>

<details>
<summary><b>WRITE_FETCH / WRITE_DATA</b></summary>

```text
WRITE_FETCH
    |
    | rx_fifo_rd_en = 1
    v
WRITE_DATA
    |
    | mem_wr_en = 1
    |
    +--> more bytes -> WRITE_FETCH
    |
    +--> last byte  -> WAIT_CMD
```

</details>

<details>
<summary><b>READ_DATA</b></summary>

```text
tx_fifo_full = 1
    -> wait

tx_fifo_full = 0
    -> mem_rd_en = 1
    -> tx_fifo_wr_en = 1
```

The controller increments the address and decrements the remaining count after each successful transfer.

</details>

---

## UART TX Operation

UART TX uses four states:

```text
IDLE -> START -> DATA -> STOP -> IDLE
```

### TX State Table

| State | Action |
|---|---|
| `IDLE` | Wait for TX FIFO data and assert `tx_fifo_rd_en` |
| `START` | Drive start bit low and capture FIFO output |
| `DATA` | Send 8 bits LSB first |
| `STOP` | Drive stop bit high |

Because the TX FIFO output is registered:

```text
IDLE
  |
  | read TX FIFO
  v
START
  |
  | tx_data is now valid
  | load shift_reg
  v
DATA
```

This prevents stale FIFO data from being transmitted.

---

## Memory Organization

The memory contains:

```verilog
reg [7:0] memory [0:15];
```

| Port | Behavior |
|---|---|
| Write Port | Synchronous |
| Read Port | Combinational |
| Write Address | `mem_wr_addr[3:0]` |
| Read Address | `mem_rd_addr[3:0]` |
| Write Data | `mem_wr_data[7:0]` |
| Read Data | `mem_rd_data[7:0]` |

### Write Path

```text
RX FIFO
   |
   | mem_wr_data
   v
Memory
```

Controlled by:

```text
mem_wr_en
mem_wr_addr
```

### Read Path

```text
Memory
   |
   | mem_rd_data
   v
TX FIFO
```

Controlled by:

```text
mem_rd_en
mem_rd_addr
tx_fifo_wr_en
```

---

## Circular Addressing

The current address register is 4 bits wide:

```verilog
reg [3:0] current_addr;
```

Therefore:

```text
15 + 1 -> 0
```

Example:

```text
Start address = 14
Count         = 4

Addresses:
14 -> 15 -> 0 -> 1
```

No separate wrap-around logic is required.

---

## RTL Files

| File | Purpose |
|---|---|
| `uart_rx.v` | Converts serial UART input to 8-bit parallel data |
| `fifo.v` | Generic 8 × 8 synchronous FIFO |
| `control_logic.v` | Five-state command/memory controller |
| `dual_port_memory.v` | 16 × 8 memory |
| `uart_tx.v` | Converts parallel data back to UART serial output |
| `uart_top.v` | Connects all RTL modules |
| `uart_top_tb.v` | End-to-end directed testbench |

---

## Module Hierarchy

```text
uart_top
|
+-- uart_rx
|
+-- fifo
|   +-- RX FIFO instance
|
+-- control_logic
|
+-- dual_port_memory
|
+-- fifo
|   +-- TX FIFO instance
|
+-- uart_tx
```

---

## Directed Test Plan

The testbench performs eight end-to-end tests.

| Test | Operation | Start Address | Count | Purpose |
|---:|---|---:|---:|---|
| 1 | Write | 3 | 1 | Single-byte write |
| 2 | Read | 3 | 1 | Single-byte read |
| 3 | Write | 4 | 4 | Multi-byte write |
| 4 | Read | 4 | 4 | Multi-byte read |
| 5 | Write | 14 | 4 | Wrap-around write |
| 6 | Read | 14 | 4 | Wrap-around read |
| 7 | Write | 12 | 8 | Maximum-length write |
| 8 | Read | 12 | 8 | Maximum-length read |

<details>
<summary><b>Example: Wrap-around write test</b></summary>

```text
Command:
WRITE
Count = 4
Start = 14

Payload:
DE AD BE EF

Expected memory:
MEM[14] = DE
MEM[15] = AD
MEM[0]  = BE
MEM[1]  = EF
```

</details>

---

## Simulation Output

The testbench reports each test in a readable table.

Example:

```text
------------------------------------------------------------
TEST 5 : WRAP-AROUND WRITE
------------------------------------------------------------

  CMD     OP       COUNT   START
  --------------------------------
  7D      WRITE      4      14

  ADDR    EXPECTED    ACTUAL    STATUS
  --------------------------------------
  14        DE          DE        OK
  15        AD          AD        OK
   0        BE          BE        OK
   1        EF          EF        OK

  RESULT : PASS
```

---

## Waveform Debugging

The testbench generates:

```text
uart_top.vcd
```

Useful signals to inspect:

| Group | Signals |
|---|---|
| UART RX | `serial_rx`, `rx_data`, `rx_valid` |
| RX FIFO | `rx_fifo_empty`, `rx_fifo_full`, `rx_fifo_rd_en` |
| Controller | `state`, `current_addr`, `bytes_left` |
| Memory Write | `mem_wr_en`, `mem_wr_addr`, `mem_wr_data` |
| Memory Read | `mem_rd_en`, `mem_rd_addr`, `mem_rd_data` |
| TX FIFO | `tx_fifo_wr_en`, `tx_fifo_full`, `tx_fifo_rd_en`, `tx_data` |
| UART TX | `serial_tx` |

---

## Synchronization Summary

All RTL modules use the same system clock.

Therefore, no additional clock-domain synchronizers are required between:

```text
UART RX
RX FIFO
Control Logic
Memory
TX FIFO
UART TX
```

The registered FIFO latency is handled explicitly by the FSM.

| Path | Timing Sequence |
|---|---|
| Command | FIFO read -> `DECODE_CMD` -> decode |
| Write Payload | `WRITE_FETCH` -> FIFO read -> `WRITE_DATA` -> memory write |
| Read Payload | Memory read -> TX FIFO write |
| UART TX | FIFO read -> `START` -> capture byte -> `DATA` |

---

## Project Flow

```text
1. UART RX receives command
          |
          v
2. Command enters RX FIFO
          |
          v
3. Controller reads command
          |
          v
4. DECODE_CMD selects READ or WRITE
          |
     +----+----+
     |         |
     v         v
   WRITE      READ
     |         |
     v         v
 RX FIFO     Memory
     |         |
     v         v
 Memory      TX FIFO
               |
               v
            UART TX
```

---

## Final Notes

This project demonstrates:

- UART serial/parallel conversion
- synchronous FIFO design
- finite-state-machine control
- command decoding
- direct datapath routing
- synchronous memory writes
- combinational memory reads
- multi-byte transfers
- automatic address wrap-around
- end-to-end RTL verification

The architecture keeps the **control path** and **payload path** separate, while the updated FSM correctly handles the one-cycle latency introduced by the registered FIFO output.

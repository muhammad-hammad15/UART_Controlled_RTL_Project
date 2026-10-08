# UART Controlled Memory Interface

Verilog RTL implementation of the UART-to-memory project architecture.

## Fixed project assumptions

- UART format: 1 start bit, 8 data bits, 1 stop bit, no parity.
- No baud-rate generator is used because the assignment does not specify a baud rate.
- One UART bit is transferred per system-clock cycle.
- RX FIFO: 8 entries x 8 bits.
- TX FIFO: 8 entries x 8 bits.
- Memory: 16 locations x 8 bits, one read port and one write port.
- Command byte:
  - `[7:5]` transfer count encoding: `000 = 1 byte` through `111 = 8 bytes`.
  - `[4:1]` starting memory address.
  - `[0]` operation: `1 = write`, `0 = read`.
- Memory address increments after each transferred byte and wraps automatically from 15 to 0.

## Data path

- UART RX -> RX FIFO: `rx_data[7:0]`.
- RX FIFO -> memory write port: `mem_wr_data[7:0]` directly.
- Memory read port -> TX FIFO: `mem_rd_data[7:0]` directly.
- TX FIFO -> UART TX: `tx_data[7:0]`.

The controller does not forward memory payload data. It only generates FIFO, address, read/write, and transfer-control signals.

### Required command-word tap

The FSM must still inspect the 8-bit command at the head of the RX FIFO to decode count, starting address, and W/R. Therefore the existing RX FIFO head bus is also connected to the controller as `rx_data_decode`. This is only a command decode tap; write payload bytes still travel directly from the RX FIFO to the memory write-data port.

Without this tap, the command decoder cannot determine `[7:5]`, `[4:1]`, or `[0]` from the defined command format.

## Files

- `uart_rx.v`
- `rx_fifo.v`
- `control_logic.v`
- `dual_port_memory.v`
- `tx_fifo.v`
- `uart_tx.v`
- `uart_memory_top.v`
- `uart_memory_top_tb.v`

## Directed tests

The testbench performs eight end-to-end tests:

1. Single-byte write.
2. Single-byte read.
3. Four-byte write.
4. Four-byte read.
5. Four-byte wrap-around write from address 14.
6. Four-byte wrap-around read from address 14.
7. Maximum eight-byte write from address 12 with wrap-around.
8. Maximum eight-byte read from address 12.

The testbench also generates `uart_memory.vcd` for waveform inspection.

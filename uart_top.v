`timescale 1ns/1ps

module uart_top (
    input  clk,
    input  rst,
    input  serial_rx,
    output serial_tx
);

    // RX FIFO signals
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_fifo_full;
    wire       rx_fifo_empty;
    wire       rx_fifo_rd_en;
    wire [7:0] mem_wr_data;

    // Memory signals
    wire       mem_wr_en;
    wire [3:0] mem_wr_addr;
    wire       mem_rd_en;
    wire [3:0] mem_rd_addr;
    wire [7:0] mem_rd_data;

    // TX FIFO signals
    wire       tx_fifo_wr_en;
    wire       tx_fifo_full;
    wire       tx_fifo_rd_en;
    wire       tx_fifo_empty;
    wire [7:0] tx_data;

    // UART Receiver
    uart_rx u_uart_rx (
        .clk          (clk),
        .rst          (rst),
        .serial_rx    (serial_rx),
        .rx_fifo_full (rx_fifo_full),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid)
    );

    // RX FIFO
    fifo u_rx_fifo (
        .clk        (clk),
        .rst        (rst),
        .data_in    (rx_data),
        .fifo_wr_en (rx_valid),
        .fifo_rd_en (rx_fifo_rd_en),
        .data_out   (mem_wr_data),
        .fifo_empty (rx_fifo_empty),
        .fifo_full  (rx_fifo_full)
    );

    // Control Logic
    control_logic u_control_logic (
        .clk            (clk),
        .rst            (rst),
        .rx_fifo_empty  (rx_fifo_empty),
        .rx_fifo_rd_en  (rx_fifo_rd_en),
        .rx_data_decode (mem_wr_data),
        .mem_wr_en      (mem_wr_en),
        .mem_wr_addr    (mem_wr_addr),
        .mem_rd_en      (mem_rd_en),
        .mem_rd_addr    (mem_rd_addr),
        .tx_fifo_full   (tx_fifo_full),
        .tx_fifo_wr_en  (tx_fifo_wr_en)
    );

    // Memory
    dual_port_memory u_memory (
        .clk         (clk),
        .rst         (rst),
        .mem_wr_en   (mem_wr_en),
        .mem_wr_addr (mem_wr_addr),
        .mem_wr_data (mem_wr_data),
        .mem_rd_en   (mem_rd_en),
        .mem_rd_addr (mem_rd_addr),
        .mem_rd_data (mem_rd_data)
    );

    // TX FIFO
    fifo u_tx_fifo (
        .clk        (clk),
        .rst        (rst),
        .data_in    (mem_rd_data),
        .fifo_wr_en (tx_fifo_wr_en),
        .fifo_rd_en (tx_fifo_rd_en),
        .data_out   (tx_data),
        .fifo_empty (tx_fifo_empty),
        .fifo_full  (tx_fifo_full)
    );

    // UART Transmitter
    uart_tx u_uart_tx (
        .clk           (clk),
        .rst           (rst),
        .tx_data       (tx_data),
        .tx_empty      (tx_fifo_empty),
        .tx_fifo_rd_en (tx_fifo_rd_en),
        .serial_tx     (serial_tx)
    );

endmodule
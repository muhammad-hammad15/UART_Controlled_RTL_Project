`timescale 1ns/1ps

module uart_rx_tb;

    reg        clk;
    reg        rst;
    reg        serial_rx;
    reg        rx_fifo_full;

    wire [7:0] rx_data;
    wire       rx_valid;

    // DUT
    uart_rx dut (
        .clk          (clk),
        .rst          (rst),
        .serial_rx    (serial_rx),
        .rx_fifo_full (rx_fifo_full),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid)
    );

     
    // Clock: 10 ns period
     
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

     
    // Send one UART bit
    // The bit is changed on the falling edge.
    // DUT samples it on the following rising edge.
     
    task send_bit(input bit_value);
        begin
            @(negedge clk);
            serial_rx = bit_value;
        end
    endtask

     
    // Send one UART byte
    // UART format:
    //     Start bit = 0, 8 data bits, LSB first, Stop bit = 1
     
    task send_uart_byte(input [7:0] data);
        integer i;

        begin
            // Start bit
            send_bit(1'b0);

            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                send_bit(data[i]);
            end

            // Stop bit
            send_bit(1'b1);
        end
    endtask

     
    // Test
   initial begin
   
    rst          = 1'b1;
    serial_rx    = 1'b1;
    rx_fifo_full = 1'b0;

    // Reset
    repeat (2) @(posedge clk);
    rst = 1'b0;

    repeat (2) @(posedge clk);

     
    // TEST 1
    $display("====================================");
    $display("TEST 1: Sending 0xA5");
    $display("====================================");

    send_uart_byte(8'hA5);

    // DUT samples STOP here
    @(posedge clk);
    #1;   // Allow NBA assignments to update

    if (rx_valid && rx_data == 8'hA5)
        $display("TEST 1 PASSED: rx_data = %h", rx_data);
    else
        $display("TEST 1 FAILED: rx_data = %h, rx_valid = %b",
                 rx_data, rx_valid);

     
    // TEST 2
    repeat (2) @(posedge clk);

    $display("====================================");
    $display("TEST 2: Sending 0x3C");
    $display("====================================");

    send_uart_byte(8'h3C);

    @(posedge clk);
    #1;

    if (rx_valid && rx_data == 8'h3C)
        $display("TEST 2 PASSED: rx_data = %h", rx_data);
    else
        $display("TEST 2 FAILED: rx_data = %h, rx_valid = %b",
                 rx_data, rx_valid);

     
    // TEST 3
    repeat (2) @(posedge clk);

    $display("====================================");
    $display("TEST 3: FIFO FULL");
    $display("====================================");

    rx_fifo_full = 1'b1;

    send_uart_byte(8'h55);

    @(posedge clk);
    #1;

    if (!rx_valid)
        $display("TEST 3 PASSED: Data blocked when FIFO is full");
    else
        $display("TEST 3 FAILED: rx_valid should be 0");

    rx_fifo_full = 1'b0;


     
    // END
    repeat (2) @(posedge clk);

    $display("====================================");
    $display("Simulation completed");
    $display("====================================");

    $finish;
end
     
    // VCD dump
    initial begin
        $dumpfile("uart_rx.vcd");
        $dumpvars(0, uart_rx_tb);
    end

endmodule
`timescale 1ns/1ps

module uart_top_tb;

    reg clk;
    reg rst;
    reg serial_rx;
    wire serial_tx;
    reg test_pass [1:8];
    reg [7:0] received_byte;

    integer i;
    integer passed;

    uart_top DUT (
        .clk       (clk),
        .rst       (rst),
        .serial_rx (serial_rx),
        .serial_tx (serial_tx)
    );

    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Command = [count-1][start address][W/R]
    function [7:0] make_cmd;
        input [3:0] byte_count;
        input [3:0] start_addr;
        input       write_not_read;

        begin
            make_cmd = {
                byte_count - 1'b1,
                start_addr,
                write_not_read
            };
        end
    endfunction

    // Send one UART byte
    task send_uart_byte;
        input [7:0] data;
        integer bit_i;

        begin
            @(negedge clk);
            serial_rx = 1'b0;

            for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                @(negedge clk);
                serial_rx = data[bit_i];
            end

            @(negedge clk);
            serial_rx = 1'b1;

            @(negedge clk);
            serial_rx = 1'b1;
        end
    endtask

    // Send and display command
    task send_command;
        input [3:0] byte_count;
        input [3:0] start_addr;
        input       write_not_read;

        reg [7:0] cmd;

        begin
            cmd = make_cmd(
                byte_count,
                start_addr,
                write_not_read
            );

            $display("  CMD     OP       COUNT   START");
            $display("  --------------------------------");

            if (write_not_read)
                $display("  %02h      WRITE      %0d      %0d",
                         cmd, byte_count, start_addr);
            else
                $display("  %02h      READ       %0d      %0d",
                         cmd, byte_count, start_addr);

            $display("");

            send_uart_byte(cmd);
        end
    endtask

    // Receive one UART byte
    task receive_uart_byte;
        output [7:0] data;
        integer bit_i;

        begin
            data = 8'd0;

            @(negedge serial_tx);
            @(negedge clk);

            for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                @(negedge clk);
                data[bit_i] = serial_tx;
            end

            @(negedge clk);

            if (serial_tx !== 1'b1)
                $display("  Warning: invalid UART stop bit");
        end
    endtask

    // Memory table header
    task memory_header;
        begin
            $display("  ADDR    EXPECTED    ACTUAL    STATUS");
            $display("  --------------------------------------");
        end
    endtask

    // Check one memory location
    task check_memory;
        input [31:0] test_no;
        input [3:0]  address;
        input [7:0]  expected;

        reg [7:0] actual;

        begin
            actual = DUT.u_memory.memory[address];

            if (actual === expected)
                $display("  %2d        %02h         %02h       OK",
                         address, expected, actual);

            else begin
                $display("  %2d        %02h         %02h       FAIL",
                         address, expected, actual);

                test_pass[test_no] = 1'b0;
            end
        end
    endtask

    // UART output table header
    task uart_header;
        begin
            $display("  BYTE    EXPECTED    RECEIVED    STATUS");
            $display("  ----------------------------------------");
        end
    endtask

    // Check one UART output byte
    task check_uart_byte;
        input [31:0] test_no;
        input [31:0] byte_no;
        input [7:0]  expected;

        begin
            receive_uart_byte(received_byte);

            if (received_byte === expected)
                $display("  %2d        %02h          %02h        OK",
                         byte_no, expected, received_byte);

            else begin
                $display("  %2d        %02h          %02h        FAIL",
                         byte_no, expected, received_byte);

                test_pass[test_no] = 1'b0;
            end
        end
    endtask

    // Test heading
    task test_header;
        input [31:0] test_no;
        input [8*32-1:0] test_name;

        begin
            $display("------------------------------------------------------------");
            $display("TEST %0d : %s", test_no, test_name);
            $display("------------------------------------------------------------");
        end
    endtask

    // Final result for one test
    task show_result;
        input [31:0] test_no;

        begin
            $display("");

            if (test_pass[test_no])
                $display("  RESULT : PASS");
            else
                $display("  RESULT : FAIL");

            $display("");
        end
    endtask

    initial begin

        $dumpfile("uart_top.vcd");
        $dumpvars(0, uart_top_tb);

        rst       = 1'b1;
        serial_rx = 1'b1;

        for (i = 1; i <= 8; i = i + 1)
            test_pass[i] = 1'b1;

        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);
          
        // TEST 1
        test_header(1, "SINGLE-BYTE WRITE");

        send_command(4'd1, 4'd3, 1'b1);

        $display("  Payload : A5");
        $display("");

        send_uart_byte(8'hA5);

        repeat (4) @(posedge clk);

        memory_header;
        check_memory(1, 4'd3, 8'hA5);

        show_result(1);

        // TEST 2
        test_header(2, "SINGLE-BYTE READ");

        send_command(4'd1, 4'd3, 1'b0);

        uart_header;
        check_uart_byte(2, 1, 8'hA5);

        show_result(2);

        // TEST 3
        test_header(3, "FOUR-BYTE WRITE");

        send_command(4'd4, 4'd4, 1'b1);

        $display("  Payload : 11 22 33 44");
        $display("  Address : 4  5  6  7");
        $display("");

        send_uart_byte(8'h11);
        send_uart_byte(8'h22);
        send_uart_byte(8'h33);
        send_uart_byte(8'h44);

        repeat (4) @(posedge clk);

        memory_header;

        check_memory(3, 4'd4, 8'h11);
        check_memory(3, 4'd5, 8'h22);
        check_memory(3, 4'd6, 8'h33);
        check_memory(3, 4'd7, 8'h44);

        show_result(3);
          
        // TEST 4
        test_header(4, "FOUR-BYTE READ");

        send_command(4'd4, 4'd4, 1'b0);

        $display("  Address : 4 5 6 7");
        $display("");

        uart_header;

        check_uart_byte(4, 1, 8'h11);
        check_uart_byte(4, 2, 8'h22);
        check_uart_byte(4, 3, 8'h33);
        check_uart_byte(4, 4, 8'h44);

        show_result(4);

        // TEST 5
        send_command(4'd4, 4'd14, 1'b1);

        $display("  Payload : DE AD BE EF");
        $display("  Address : 14 15 0 1");
        $display("");

        send_uart_byte(8'hDE);
        send_uart_byte(8'hAD);
        send_uart_byte(8'hBE);
        send_uart_byte(8'hEF);

        repeat (4) @(posedge clk);

        memory_header;

        check_memory(5, 4'd14, 8'hDE);
        check_memory(5, 4'd15, 8'hAD);
        check_memory(5, 4'd0,  8'hBE);
        check_memory(5, 4'd1,  8'hEF);

        show_result(5);
          
        // TEST 6          
        test_header(6, "WRAP-AROUND READ");

        send_command(4'd4, 4'd14, 1'b0);

        $display("  Address : 14 15 0 1");
        $display("");

        uart_header;

        check_uart_byte(6, 1, 8'hDE);
        check_uart_byte(6, 2, 8'hAD);
        check_uart_byte(6, 3, 8'hBE);
        check_uart_byte(6, 4, 8'hEF);

        show_result(6);
          
        // TEST 7
        test_header(7, "EIGHT-BYTE WRITE");

        send_command(4'd8, 4'd12, 1'b1);

        $display("  Payload : 10 11 12 13 14 15 16 17");
        $display("  Address : 12 13 14 15 0  1  2  3");
        $display("");

        send_uart_byte(8'h10);
        send_uart_byte(8'h11);
        send_uart_byte(8'h12);
        send_uart_byte(8'h13);
        send_uart_byte(8'h14);
        send_uart_byte(8'h15);
        send_uart_byte(8'h16);
        send_uart_byte(8'h17);

        repeat (4) @(posedge clk);

        memory_header;

        check_memory(7, 4'd12, 8'h10);
        check_memory(7, 4'd13, 8'h11);
        check_memory(7, 4'd14, 8'h12);
        check_memory(7, 4'd15, 8'h13);
        check_memory(7, 4'd0,  8'h14);
        check_memory(7, 4'd1,  8'h15);
        check_memory(7, 4'd2,  8'h16);
        check_memory(7, 4'd3,  8'h17);

        show_result(7);
          
        // TEST 8
        test_header(8, "EIGHT-BYTE READ");

        send_command(4'd8, 4'd12, 1'b0);

        $display("  Address : 12 13 14 15 0 1 2 3");
        $display("");

        uart_header;

        check_uart_byte(8, 1, 8'h10);
        check_uart_byte(8, 2, 8'h11);
        check_uart_byte(8, 3, 8'h12);
        check_uart_byte(8, 4, 8'h13);
        check_uart_byte(8, 5, 8'h14);
        check_uart_byte(8, 6, 8'h15);
        check_uart_byte(8, 7, 8'h16);
        check_uart_byte(8, 8, 8'h17);

        show_result(8);


        // FINAL SUMMARY
        passed = 0;

        for (i = 1; i <= 8; i = i + 1)
            if (test_pass[i])
                passed = passed + 1;


        $display("============================================================");
        $display("DIRECTED TEST SUMMARY");
        $display("============================================================");
        $display("  TEST        STATUS");
        $display("  ------------------");

        for (i = 1; i <= 8; i = i + 1) begin

            if (test_pass[i])
                $display("   %0d          PASS", i);
            else
                $display("   %0d          FAIL", i);

        end

        $display("  ------------------");
        $display("  Passed      %0d / 8", passed);
        $display("  Failed      %0d", 8 - passed);
        $display("============================================================");

        #50;
        $finish;

    end

endmodule
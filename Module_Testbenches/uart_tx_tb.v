`timescale 1ns/1ps

module uart_tx_tb;

    reg        clk;
    reg        rst;
    reg [7:0]  tx_data;
    reg        tx_empty;

    wire       tx_fifo_rd_en;
    wire       serial_tx;

    integer i;
    integer errors;


    // DUT
    uart_tx dut (
        .clk           (clk),
        .rst           (rst),
        .tx_data       (tx_data),
        .tx_empty      (tx_empty),
        .tx_fifo_rd_en (tx_fifo_rd_en),
        .serial_tx     (serial_tx)
    );


    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // Reset
    task reset_dut;
        begin
            rst      = 1'b1;
            tx_data  = 8'h00;
            tx_empty = 1'b1;

            repeat (2) @(posedge clk);
            rst = 1'b0;

            @(negedge clk);
        end
    endtask


    // Send one byte
    task send_byte(input [7:0] data);
        begin
            tx_data  = data;
            tx_empty = 1'b0;
        end
    endtask


    // Check one transmitted bit
    task check_bit(input expected_bit);
        begin
            #1;

            if (serial_tx !== expected_bit) begin
                $display("  Bit[%0d] : FAIL | Expected=%b Actual=%b",
                         i, expected_bit, serial_tx);
                errors = errors + 1;
            end
            else begin
                $display("  Bit[%0d] : PASS | Value=%b",
                         i, serial_tx);
            end

            @(posedge clk);
        end
    endtask


    initial begin

        errors = 0;

        $display("");
        $display("================================================");
        $display("             UART TX VERIFICATION");
        $display("================================================");
        $display("Configuration : 8-bit data | LSB first");
        $display("Verification  : Start / Data / Stop");
        $display("------------------------------------------------");


        // Reset
        reset_dut;


        // TEST 1
        $display("");
        $display("[TEST 1] Reset and Idle State");
        $display("  Expected : serial_tx=1, FIFO read disabled");

        #1;

        if (serial_tx == 1'b1 &&
            tx_fifo_rd_en == 1'b0)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");


        // TEST 2
        $display("");
        $display("[TEST 2] FIFO Data Request");
        $display("  Input    : 0xA5");

        send_byte(8'hA5);

        #1;

        if (tx_fifo_rd_en == 1'b1)
            $display("  FIFO Read Enable : PASS");
        else
            $display("  FIFO Read Enable : FAIL");


        // Capture data at clock edge
        @(posedge clk);
        #1;

        tx_empty = 1'b1;


        // TEST 3
        $display("");
        $display("[TEST 3] Start Bit");
        $display("  Expected : serial_tx=0");

        if (serial_tx == 1'b0)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");


        // Move to DATA state
        @(posedge clk);
        #1;

        // TEST 4
        $display("");
        $display("[TEST 4] Data Bits");
        $display("  Data     : 0xA5");
        $display("  Expected : LSB first");

        for (i = 0; i < 8; i = i + 1) begin

            #1;

            if (serial_tx !== ((8'hA5 >> i) & 1'b1)) begin
                $display("  Bit[%0d] : FAIL | Expected=%b Actual=%b",
                         i, ((8'hA5 >> i) & 1'b1), serial_tx);
                errors = errors + 1;
            end
            else begin
                $display("  Bit[%0d] : PASS | Value=%b",
                         i, serial_tx);
            end

            @(posedge clk);
            #1;
        end

        // TEST 5
        $display("");
        $display("[TEST 5] Stop Bit");
        $display("  Expected : serial_tx=1");

        if (serial_tx == 1'b1)
            $display("  Result   : PASS");
        else begin
            $display("  Result   : FAIL");
            errors = errors + 1;
        end

        @(posedge clk);
        #1;


        // TEST 6
        $display("");
        $display("[TEST 6] Return to Idle");
        $display("  Expected : serial_tx=1, FIFO read disabled");

        if (serial_tx == 1'b1 &&
            tx_fifo_rd_en == 1'b0)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");


        // FINAL
        $display("");
        $display("================================================");

        if (errors == 0)
            $display("          ALL TEST CASES PASSED");
        else
            $display("          TEST FAILED | Errors=%0d", errors);

        $display("================================================");
        $display("          VERIFICATION COMPLETE");
        $display("================================================");
        $display("");

        #20;
        $finish;
    end


    // Waveform
    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, uart_tx_tb);
    end

endmodule
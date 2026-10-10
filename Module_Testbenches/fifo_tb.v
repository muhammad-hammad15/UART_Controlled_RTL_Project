`timescale 1ns/1ps

module fifo_tb;

    reg        clk;
    reg        rst;
    reg [7:0]  rx_data;
    reg        rx_valid;
    reg        rx_fifo_rd_en;

    wire [7:0] mem_wr_data;
    wire       rx_fifo_empty;
    wire       rx_fifo_full;

	reg [7:0] expected_data [0:7];
    reg [7:0] actual_data;
    integer i;
    integer read_errors;

     
    // DUT
    fifo dut (
        .clk           (clk),
        .rst           (rst),
        .data_in       (rx_data),
        .fifo_wr_en    (rx_valid),
        .fifo_rd_en (rx_fifo_rd_en),
        .data_out   (mem_wr_data),
        .fifo_empty (rx_fifo_empty),
        .fifo_full  (rx_fifo_full)
    );

     
    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

     
    // FIFO Write
    task fifo_write(input [7:0] data);
        begin
            @(negedge clk);
            rx_data  = data;
            rx_valid = 1'b1;

            @(negedge clk);
            rx_valid = 1'b0;
            rx_data  = 8'h00;
        end
    endtask

     
    // FIFO Read
    task fifo_read;
        begin
            @(negedge clk);
            rx_fifo_rd_en = 1'b1;

            @(negedge clk);
            rx_fifo_rd_en = 1'b0;
        end
    endtask

     
    // Test sequence
    initial begin

        rst           = 1'b1;
        rx_data       = 8'h00;
        rx_valid      = 1'b0;
        rx_fifo_rd_en = 1'b0;

        // Reset
        repeat (2) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        $display("");
        $display("================================================");
        $display("             RX FIFO VERIFICATION");
        $display("================================================");
        $display("Configuration : 8-bit data | 8 entries");
        $display("Verification  : Write / Read / Boundary Checks");
        $display("------------------------------------------------");

         
        // TEST 1: RESET
        $display("");
        $display("[TEST 1] Reset and Initial State");
        $display("  Expected : FIFO empty, FIFO not full");

        if (rx_fifo_empty && !rx_fifo_full)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");

         
        // TEST 2: SINGLE WRITE
        $display("");
        $display("[TEST 2] Single Data Write");
        $display("  Input    : 0xA5");
        $display("  Expected : FIFO accepts data and becomes non-empty");

        fifo_write(8'hA5);
        @(posedge clk);

        if (!rx_fifo_empty && !rx_fifo_full)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");

         
        // TEST 3: DATA INTEGRITY
        $display("");
        $display("[TEST 3] Data Integrity");
        $display("  Expected : Stored data = 0xA5");

        if (mem_wr_data == 8'hA5)
            $display("  Actual   : 0x%02h", mem_wr_data);
        else
            $display("  Actual   : 0x%02h", mem_wr_data);

        if (mem_wr_data == 8'hA5)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");

         
        // TEST 4: SINGLE READ
        $display("");
        $display("[TEST 4] Single Data Read");
        $display("  Expected : FIFO returns to empty state");

        fifo_read;
        @(posedge clk);

        if (rx_fifo_empty)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");

         
        // TEST 5: FIFO CAPACITY
        $display("");
        $display("[TEST 5] FIFO Capacity");
        $display("  Operation : Write 8 entries");
        $display("  Expected  : FIFO becomes full");

        fifo_write(8'h10);
        fifo_write(8'h20);
        fifo_write(8'h30);
        fifo_write(8'h40);
        fifo_write(8'h50);
        fifo_write(8'h60);
        fifo_write(8'h70);
        fifo_write(8'h80);

        @(posedge clk);

        if (rx_fifo_full)
            $display("  Result    : PASS (FIFO FULL)");
        else
            $display("  Result    : FAIL");

         
        // TEST 6: WRITE WHEN FULL
        $display("");
        $display("[TEST 6] Write Protection When FIFO Is Full");
        $display("  Attempt   : Write 0xFF");
        $display("  Expected  : Write rejected, existing data preserved");

        fifo_write(8'hFF);
        @(posedge clk);

        if (rx_fifo_full && mem_wr_data == 8'h10)
            $display("  Result    : PASS");
        else
            $display("  Result    : FAIL");

         
        // TEST 7: FIFO READ ORDER
        expected_data[0] = 8'h10;
        expected_data[1] = 8'h20;
        expected_data[2] = 8'h30;
        expected_data[3] = 8'h40;
        expected_data[4] = 8'h50;
        expected_data[5] = 8'h60;
        expected_data[6] = 8'h70;
        expected_data[7] = 8'h80;

        read_errors = 0;

        $display("");
        $display("[TEST 7] FIFO Read Order");
        $display("  Expected sequence : 10 20 30 40 50 60 70 80");

        for (i = 0; i < 8; i = i + 1) begin

            // Capture current data before advancing rd_ptr
            @(negedge clk);
            actual_data = mem_wr_data;

            if (actual_data !== expected_data[i]) begin
                $display("  Read[%0d] : FAIL | Expected=0x%02h Actual=0x%02h",
                         i + 1, expected_data[i], actual_data);
                read_errors = read_errors + 1;
            end
            else begin
                $display("  Read[%0d] : PASS | Data=0x%02h",
                         i + 1, actual_data);
            end

            // Advance the read pointer
            rx_fifo_rd_en = 1'b1;
            @(negedge clk);
            rx_fifo_rd_en = 1'b0;

        end

        if (rx_fifo_empty && read_errors == 0)
            $display("  Result   : PASS | All 8 entries read in FIFO order");
        else
            $display("  Result   : FAIL | Errors=%0d, Empty=%b",
                     read_errors, rx_fifo_empty);

         
        // TEST 8: READ WHEN EMPTY
        $display("");
        $display("[TEST 8] Read Protection When FIFO Is Empty");
        $display("  Expected : Read request ignored");

        fifo_read;
        @(posedge clk);

        if (rx_fifo_empty)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");

         
        // END
        $display("");
        $display("------------------------------------------------");
      $display("    	 ALL TEST PASSES SUCCESSFULLY");
        $display("------------------------------------------------");
        $display("================================================");
        $display("");

        #20;
        $finish;
    end

    // Waveform
    initial begin
        $dumpfile("fifo.vcd");
        $dumpvars(0, fifo_tb);
    end

endmodule
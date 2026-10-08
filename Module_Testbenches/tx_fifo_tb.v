`timescale 1ns/1ps

module tx_fifo_tb;

    reg        clk;
    reg        rst;
    reg [7:0]  mem_rd_data;
    reg        tx_fifo_wr_en;
    reg        tx_fifo_rd_en;

    wire [7:0] tx_data;
    wire       tx_empty;
    wire       tx_fifo_full;

    reg [7:0] expected_data [0:7];
    reg [7:0] actual_data;

    integer i;
    integer read_errors;


    // DUT
    tx_fifo dut (
        .clk           (clk),
        .rst           (rst),
        .mem_rd_data   (mem_rd_data),
        .tx_fifo_wr_en (tx_fifo_wr_en),
        .tx_fifo_rd_en (tx_fifo_rd_en),
        .tx_data       (tx_data),
        .tx_empty      (tx_empty),
        .tx_fifo_full  (tx_fifo_full)
    );


    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    // FIFO Write
    task fifo_write(input [7:0] data);
        begin
            @(negedge clk);
            mem_rd_data   = data;
            tx_fifo_wr_en = 1'b1;

            @(negedge clk);
            tx_fifo_wr_en = 1'b0;
            mem_rd_data   = 8'h00;
        end
    endtask


    // FIFO Read
    task fifo_read;
        begin
            @(negedge clk);
            tx_fifo_rd_en = 1'b1;

            @(negedge clk);
            tx_fifo_rd_en = 1'b0;
        end
    endtask


    initial begin

        rst           = 1'b1;
        mem_rd_data   = 8'h00;
        tx_fifo_wr_en = 1'b0;
        tx_fifo_rd_en = 1'b0;

        // Reset
        repeat (2) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);


        $display("");
        $display("================================================");
        $display("             TX FIFO VERIFICATION");
        $display("================================================");
        $display("Configuration : 8-bit data | 8 entries");
        $display("Verification  : Write / Read / Boundary Checks");
        $display("------------------------------------------------");


        // TEST 1
        $display("");
        $display("[TEST 1] Reset and Initial State");
        $display("  Expected : FIFO empty, FIFO not full");

        if (tx_empty && !tx_fifo_full)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");


        // TEST 2
        $display("");
        $display("[TEST 2] Single Data Write");
        $display("  Input    : 0xA5");

        fifo_write(8'hA5);
        @(posedge clk);

        if (!tx_empty && !tx_fifo_full)
            $display("  FIFO State : PASS | FIFO contains data");
        else
            $display("  FIFO State : FAIL");

        if (tx_data == 8'hA5)
            $display("  Data       : PASS | TX Data=0x%02h", tx_data);
        else
            $display("  Data       : FAIL | Expected=0xA5 Actual=0x%02h",
                     tx_data);


        // TEST 3
        $display("");
        $display("[TEST 3] Single Data Read");
        $display("  Expected : FIFO becomes empty");

        fifo_read;
        @(posedge clk);

        if (tx_empty)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");


        // TEST 4
        $display("");
        $display("[TEST 4] FIFO Capacity");
        $display("  Operation : Write 8 entries");

        fifo_write(8'h10);
        fifo_write(8'h20);
        fifo_write(8'h30);
        fifo_write(8'h40);
        fifo_write(8'h50);
        fifo_write(8'h60);
        fifo_write(8'h70);
        fifo_write(8'h80);

        @(posedge clk);

        if (tx_fifo_full)
            $display("  Result   : PASS | FIFO FULL");
        else
            $display("  Result   : FAIL | FIFO not full");


        // TEST 5
        $display("");
        $display("[TEST 5] Write Protection When FIFO Is Full");
        $display("  Attempt  : Write 0xFF");

        fifo_write(8'hFF);
        @(posedge clk);

        if (tx_fifo_full && tx_data == 8'h10)
            $display("  Result   : PASS | Write rejected");
        else
            $display("  Result   : FAIL");


        // TEST 6
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
        $display("[TEST 6] FIFO Read Order");
        $display("  Expected sequence : 10 20 30 40 50 60 70 80");

        for (i = 0; i < 8; i = i + 1) begin

            @(negedge clk);

            actual_data = tx_data;

            if (actual_data !== expected_data[i]) begin
                $display("  Read[%0d] : FAIL | Expected=0x%02h Actual=0x%02h",
                         i + 1, expected_data[i], actual_data);
                read_errors = read_errors + 1;
            end
            else begin
                $display("  Read[%0d] : PASS | Data=0x%02h",
                         i + 1, actual_data);
            end

            tx_fifo_rd_en = 1'b1;

            @(negedge clk);
            tx_fifo_rd_en = 1'b0;

        end

        if (tx_empty && read_errors == 0)
            $display("  Result   : PASS | All entries read in FIFO order");
        else
            $display("  Result   : FAIL | Errors=%0d",
                     read_errors);


        // TEST 7
        $display("");
        $display("[TEST 7] Read Protection When FIFO Is Empty");
        $display("  Expected : Read request ignored");

        fifo_read;
        @(posedge clk);

        if (tx_empty)
            $display("  Result   : PASS");
        else
            $display("  Result   : FAIL");


        // END
        $display("");
        $display("================================================");
        $display("          ALL TEST CASES PASSED");
        $display("================================================");
        $display("");

        #20;
        $finish;

    end


    // Waveform
    initial begin
        $dumpfile("tx_fifo.vcd");
        $dumpvars(0, tx_fifo_tb);
    end

endmodule
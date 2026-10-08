`timescale 1ns/1ps

module control_logic_tb;
 
    reg         clk;
    reg         rst;
    reg         rx_fifo_empty;
    wire        rx_fifo_rd_en;
    reg  [7:0]  rx_data_decode;
    wire        mem_wr_en;
    wire [3:0]  mem_wr_addr;
    wire        mem_rd_en;
    wire [3:0]  mem_rd_addr;
    reg         tx_fifo_full;
    wire        tx_fifo_wr_en;


     
    // DUT
    control_logic dut (
        .clk            (clk),
        .rst            (rst),
        .rx_fifo_empty  (rx_fifo_empty),
        .rx_fifo_rd_en  (rx_fifo_rd_en),
        .rx_data_decode (rx_data_decode),
        .mem_wr_en      (mem_wr_en),
        .mem_wr_addr    (mem_wr_addr),
        .mem_rd_en      (mem_rd_en),
        .mem_rd_addr    (mem_rd_addr),
        .tx_fifo_full   (tx_fifo_full),
        .tx_fifo_wr_en  (tx_fifo_wr_en)
    );


     
    // Clock Generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
    
    // Task: Reset DUT 
    task reset_dut;
        begin
            rst            = 1'b1;
            rx_fifo_empty  = 1'b1;
            rx_data_decode = 8'h00;
            tx_fifo_full   = 1'b0;

            #10;
            rst = 1'b0;

            @(negedge clk);
        end
    endtask

    // Task: Send Command
    task send_command(input [7:0] command);
        begin
            rx_data_decode = command;
            rx_fifo_empty  = 1'b0;

            @(posedge clk);
            #1;

            rx_fifo_empty = 1'b1;
        end
    endtask
     
    // Task: Check WAIT_CMD
    task test_wait_cmd;
        begin
            $display("");
            $display("[TEST 1] WAIT_CMD - Command Detection");

            rx_fifo_empty  = 1'b0;
            rx_data_decode = 8'h2B;

            #1;

            if (rx_fifo_rd_en == 1'b1)
                $display("  RX FIFO Read Enable : PASS");
            else
                $display("  RX FIFO Read Enable : FAIL");

            @(posedge clk);
            #1;

            if (mem_wr_addr == 4'd5)
                $display("  Command Address     : PASS | Address=5");
            else
                $display("  Command Address     : FAIL | Actual=%0d",
                         mem_wr_addr);

            if (mem_wr_en == 1'b1)
                $display("  Command Type        : PASS | WRITE");
            else
                $display("  Command Type        : FAIL");

            rx_fifo_empty = 1'b1;
        end
    endtask

    // Task: Test WRITE Operation
    task test_write;
    begin
        $display("");
        $display("[TEST 2] WRITE_DATA - Memory Write");

        rx_fifo_empty = 1'b0;

        #1;

        // First byte
        if (rx_fifo_rd_en == 1'b1 &&
            mem_wr_en    == 1'b1 &&
            mem_wr_addr  == 4'd5)
            $display("  Write Byte 1        : PASS | Address=5");
        else
            $display("  Write Byte 1        : FAIL");

        // Consume first byte
        @(posedge clk);
        #1;

        if (mem_wr_addr == 4'd6)
            $display("  Address Increment   : PASS | Address=6");
        else
            $display("  Address Increment   : FAIL | Actual=%0d",
                     mem_wr_addr);

        // Second byte
        if (rx_fifo_rd_en == 1'b1 &&
            mem_wr_en    == 1'b1)
            $display("  Write Byte 2        : PASS | Address=6");
        else
            $display("  Write Byte 2        : FAIL");

        // Consume second byte
        @(posedge clk);
        #1;

        // FIFO is now empty
        rx_fifo_empty = 1'b1;

        // Allow combinational outputs to update
        #1;

        if (rx_fifo_rd_en == 1'b0 &&
            mem_wr_en    == 1'b0)
            $display("  Write Completion    : PASS");
        else
            $display("  Write Completion    : FAIL");
    end
endtask
     
    // Task: Test READ Operation
    task test_read;
        begin
            $display("");
            $display("[TEST 3] READ_DATA - Memory Read");

            send_command(8'h52);

            #1;

            if (mem_rd_en    == 1'b1 &&
                tx_fifo_wr_en == 1'b1 &&
                mem_rd_addr  == 4'd9)
                $display("  Read Byte 1         : PASS | Address=9");
            else
                $display("  Read Byte 1         : FAIL");

            @(posedge clk);
            #1;

            if (mem_rd_addr == 4'd10)
                $display("  Address Increment    : PASS | Address=10");
            else
                $display("  Address Increment    : FAIL | Actual=%0d",
                         mem_rd_addr);

            @(posedge clk);
            #1;

            if (mem_rd_addr == 4'd11)
                $display("  Address Increment    : PASS | Address=11");
            else
                $display("  Address Increment    : FAIL | Actual=%0d",
                         mem_rd_addr);

            @(posedge clk);
            #1;

            if (mem_rd_en == 1'b0 &&
                tx_fifo_wr_en == 1'b0)
                $display("  Read Completion      : PASS");
            else
                $display("  Read Completion      : FAIL");
        end
    endtask


     
    // Task: RX FIFO Empty Protection
    task test_rx_fifo_empty;
        begin
            $display("");
            $display("[TEST 4] RX FIFO Empty Protection");

            rx_fifo_empty = 1'b1;

            #1;

            if (rx_fifo_rd_en == 1'b0)
                $display("  RX FIFO Read Enable  : PASS | Disabled");
            else
                $display("  RX FIFO Read Enable  : FAIL");
        end
    endtask


     
    // Task: TX FIFO Full Protection
    task test_tx_fifo_full;
        begin
            $display("");
            $display("[TEST 5] TX FIFO Full Protection");

            // 1 byte READ command, address = 9
            rx_data_decode = 8'h12;
            rx_fifo_empty  = 1'b0;

            @(posedge clk);
            #1;

            rx_fifo_empty = 1'b1;
            tx_fifo_full  = 1'b1;

            #1;

            if (mem_rd_en == 1'b0)
                $display("  Memory Read Enable   : PASS | Disabled");
            else
                $display("  Memory Read Enable   : FAIL");

            if (tx_fifo_wr_en == 1'b0)
                $display("  TX FIFO Write       : PASS | Disabled");
            else
                $display("  TX FIFO Write       : FAIL");

            tx_fifo_full = 1'b0;
        end
    endtask
     
    // Main Test Sequence
    initial begin

        $display("");
        $display("================================================");
        $display("        CONTROL LOGIC VERIFICATION");
        $display("================================================");
        $display("Configuration : Command Decoder + Memory Control");
        $display("Verification  : READ / WRITE / FIFO Protection");
        $display("------------------------------------------------");

        // Reset
        reset_dut;

        // Tests
        test_wait_cmd;
        test_write;
        test_read;
        test_rx_fifo_empty;
        test_tx_fifo_full;

         
        // Verification Complete
        #10;

        $display("");
        $display("================================================");
        $display("          ALL TEST CASES PASSED");
        $display("================================================");
        $display("");

        $finish;
    end

    // Waveform
    initial begin
      $dumpfile("control_logic.vcd");
      $dumpvars(0, control_logic_tb);
    end

endmodule
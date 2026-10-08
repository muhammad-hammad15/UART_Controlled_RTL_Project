`timescale 1ns/1ps

module dual_port_memory_tb;

    reg        clk;
    reg        rst;
    reg        mem_wr_en;
    reg  [3:0] mem_wr_addr;
    reg  [7:0] mem_wr_data;
    reg        mem_rd_en;
    reg  [3:0] mem_rd_addr;
    wire [7:0] mem_rd_data;


    // DUT
    dual_port_memory DUT (
        .clk(clk),
        .rst(rst),
        .mem_wr_en(mem_wr_en),
        .mem_wr_addr(mem_wr_addr),
        .mem_wr_data(mem_wr_data),
        .mem_rd_en(mem_rd_en),
        .mem_rd_addr(mem_rd_addr),
        .mem_rd_data(mem_rd_data)
    );


    // Clock: 10 ns period
    always #5 clk = ~clk;


    initial begin

        $dumpfile("dual_port_memory.vcd");
        $dumpvars(0, dual_port_memory_tb);

        // Display time in ns
        $timeformat(-9, 0, " ns", 8);

        // Initial values
        clk         = 0;
        rst         = 1;
        mem_wr_en   = 0;
        mem_wr_addr = 0;
        mem_wr_data = 0;
        mem_rd_en   = 0;
        mem_rd_addr = 0;


        $display("==================================================");
        $display("        DUAL PORT MEMORY TEST STARTED");
        $display("==================================================");

         
        // RESET
        $display("\n[%0t] Applying RESET", $time);
        #10;
        rst = 0;

        $display("[%0t] RESET released", $time);

        // WRITE TESTS
        $display("\n              WRITE TESTS               ");

        mem_wr_en   = 1;

        mem_wr_addr = 4'd3;
        mem_wr_data = 8'd25;
        #10;
        $display("[%0t] WRITE : Address=%0d  Data=%0d",
                 $time, mem_wr_addr, mem_wr_data);

        mem_wr_addr = 4'd7;
        mem_wr_data = 8'd50;
        #10;
        $display("[%0t] WRITE : Address=%0d  Data=%0d",
                 $time, mem_wr_addr, mem_wr_data);


        mem_wr_addr = 4'd12;
        mem_wr_data = 8'd100;
        #10;
        $display("[%0t] WRITE : Address=%0d  Data=%0d",
                 $time, mem_wr_addr, mem_wr_data);


        mem_wr_en = 0;
         
        // READ TESTS
      	$display("\n                   READ TESTS                     ");

        mem_rd_en   = 1;

        // Read address 3
        mem_rd_addr = 4'd3;
        #1;

        if (mem_rd_data == 8'd25)
            $display("[%0t] READ  : Address=3  Expected=25  Actual=%0d  --> PASS",
                     $time, mem_rd_data);
        else
            $display("[%0t] READ  : Address=3  Expected=25  Actual=%0d  --> FAIL",
                     $time, mem_rd_data);

        #9;

        // Read address 7
        mem_rd_addr = 4'd7;
        #1;

        if (mem_rd_data == 8'd50)
            $display("[%0t] READ  : Address=7  Expected=50  Actual=%0d  --> PASS",
                     $time, mem_rd_data);
        else
            $display("[%0t] READ  : Address=7  Expected=50  Actual=%0d  --> FAIL",
                     $time, mem_rd_data);

        #9;

        // Read address 12
        mem_rd_addr = 4'd12;
        #1;

        if (mem_rd_data == 8'd100)
            $display("[%0t] READ  : Address=12 Expected=100 Actual=%0d  --> PASS",
                     $time, mem_rd_data);
        else
            $display("[%0t] READ  : Address=12 Expected=100 Actual=%0d  --> FAIL",
                     $time, mem_rd_data);

        #9;

        // READ DISABLE TEST
         $display("\n                READ DISABLE TEST            ");

        mem_rd_en = 0;
        #1;

        if (mem_rd_data == 8'd0)
            $display("[%0t] READ disabled: d_out=%0d --> PASS",
                     $time, mem_rd_data);
        else
            $display("[%0t] READ disabled: d_out=%0d --> FAIL",
                     $time, mem_rd_data);

        #9;

        // SIMULTANEOUS READ / WRITE
         $display("\n      SIMULTANEOUS READ / WRITE          ");

        mem_wr_en   = 1;
        mem_wr_addr = 4'd5;
        mem_wr_data = 8'd77;

        mem_rd_en   = 1;
        mem_rd_addr = 4'd3;

        #10;

        $display("[%0t] WRITE : Address=5 Data=77", $time);
        $display("[%0t] READ  : Address=3 Data=%0d",
                 $time, mem_rd_data);

        // Read newly written address 5
        mem_wr_en   = 0;
        mem_rd_addr = 4'd5;
        #1;

        if (mem_rd_data == 8'd77)
            $display("[%0t] READ  : Address=5 Expected=77 Actual=%0d --> PASS",
                     $time, mem_rd_data);
        else
            $display("[%0t] READ  : Address=5 Expected=77 Actual=%0d --> FAIL",
                     $time, mem_rd_data);

        #9;
         
        // RESET OUTPUT TEST
      $display("\n               RESET TEST               ");

        rst = 1;
        #1;

        if (mem_rd_data == 8'd0)
            $display("[%0t] RESET active: mem_rd_data=%0d --> PASS",
                     $time, mem_rd_data);
        else
            $display("[%0t] RESET active: mem_rd_data=%0d --> FAIL",
                     $time, mem_rd_data);

        #9;


        $display("\n==================================================");
        $display("        DUAL PORT MEMORY TEST FINISHED");
        $display("==================================================");

        $finish;

    end

endmodule
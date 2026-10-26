`timescale 1ns/1ps

module dual_port_memory (
    input            clk,
    input            rst,
    input            mem_wr_en,
    input      [3:0] mem_wr_addr,
    input      [7:0] mem_wr_data,
    input            mem_rd_en,
    input      [3:0] mem_rd_addr,
    output reg [7:0] mem_rd_data
);
    // Memory 16-Depth and 8-Width 
    reg [7:0] memory [0:15];

    // Syncrohonous Write 
    always @(posedge clk) 
    begin
      if (!rst && mem_wr_en)
        memory[mem_wr_addr] <= mem_wr_data;
    end

    // Combinational Read
    always @(*) 
    begin
        if (rst)
          mem_rd_data = 8'd0;
        else if (mem_rd_en)
          mem_rd_data = memory[mem_rd_addr];
        else
          mem_rd_data = 8'd0;
    end

endmodule

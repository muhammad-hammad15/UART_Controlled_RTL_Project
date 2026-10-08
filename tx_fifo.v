`timescale 1ns/1ps

module tx_fifo (
    input            clk,
    input            rst,
    input      [7:0] mem_rd_data,
    input            tx_fifo_wr_en,
    input            tx_fifo_rd_en,
    output     [7:0] tx_data,
    output           tx_empty,
    output           tx_fifo_full
);

    // Memory
    reg [7:0] fifo_mem [0:7];
    // Counters
    reg [2:0] wr_ptr;
    reg [2:0] rd_ptr;
    reg [3:0] count;

    // Flags
    assign tx_empty     = (count == 4'd0);
    assign tx_fifo_full = (count == 4'd8);
    // Read Memory
    assign tx_data      = fifo_mem[rd_ptr];

    // Asyncrohonous Block
    always @(posedge clk or posedge rst) 
    begin
        if (rst) begin
            wr_ptr <= 3'd0;
            rd_ptr <= 3'd0;
            count  <= 4'd0;
        end
        
        else 
        begin
            if (tx_fifo_wr_en && !tx_fifo_full) 
            begin
                fifo_mem[wr_ptr] <= mem_rd_data;    // FIFO write and write pointer will increment
                wr_ptr <= wr_ptr + 1'b1;
            end

            if (tx_fifo_rd_en && !tx_empty)        // FIFO read and read pointer will increment 
                rd_ptr <= rd_ptr + 1'b1;

            // Case tells if write happens count increment, if read happens count decrement.
            // both remains same if write and read happens simultaneously 
            case ({(tx_fifo_wr_en && !tx_fifo_full), (tx_fifo_rd_en && !tx_empty)})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule

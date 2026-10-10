`timescale 1ns/1ps

module fifo (
    input            clk,
    input            rst,
    input      [7:0] data_in,
    input            fifo_wr_en,
    input            fifo_rd_en,
    output     [7:0] data_out,
    output           fifo_empty,
    output           fifo_full
);

    // Counters
    reg [2:0] wr_ptr;
    reg [2:0] rd_ptr;
    reg [3:0] count;

    // Memory
    reg [7:0] fifo_mem [0:7];

    // Flags
    assign fifo_empty = (count == 4'd0);
    assign fifo_full  = (count == 4'd8);

    // Oldest FIFO byte is always visible
    assign data_out = fifo_mem[rd_ptr];

    // Sequential block with asynchronous reset
    always @(posedge clk or posedge rst) begin
        if (rst) 
        begin
            wr_ptr   <= 3'd0;
            rd_ptr   <= 3'd0;
            count    <= 4'd0;
        end
        else 
        begin
            if (fifo_wr_en && !fifo_full) 
            begin
                fifo_mem[wr_ptr] <= data_in;       // FIFO write and write pointer will increment
                wr_ptr <= wr_ptr + 1'b1;
            end

            if (fifo_rd_en && !fifo_empty)         // FIFO read Combinationally and read pointer will increment
                rd_ptr   <= rd_ptr + 1'b1;    

            // Update FIFO count
            case ({(fifo_wr_en && !fifo_full),(fifo_rd_en && !fifo_empty)})
                2'b10: count <= count + 1'b1; // Write only
                2'b01: count <= count - 1'b1; // Read  only
                default: count <= count;      // Else count remains same
            endcase
        end
    end

endmodule
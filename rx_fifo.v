`timescale 1ns/1ps

module rx_fifo (
    input            clk,
    input            rst,
    input      [7:0] rx_data,
    input            rx_valid,
    input            rx_fifo_rd_en,
    output     [7:0] mem_wr_data,
    output           rx_fifo_empty,
    output           rx_fifo_full
);

    // Memory
    reg [7:0] fifo_mem [0:7];
    // Counters
    reg [2:0] wr_ptr;
    reg [2:0] rd_ptr;
    reg [3:0] count;

    // Flags
    assign rx_fifo_empty = (count == 4'd0);
    assign rx_fifo_full  = (count == 4'd8);
    // Memory Write
    assign mem_wr_data   = fifo_mem[rd_ptr];

    // Asyncrohonous Block
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 3'd0;
            rd_ptr <= 3'd0;
            count  <= 4'd0;
        end
        else begin
            if (rx_valid && !rx_fifo_full) 
            begin
                fifo_mem[wr_ptr] <= rx_data;       // FIFO write and write pointer will increment
                wr_ptr <= wr_ptr + 1'b1;
            end

            if (rx_fifo_rd_en && !rx_fifo_empty)   // FIFO read and read pointer will increment
                rd_ptr <= rd_ptr + 1'b1;

            // Case tells if write happens count increment, if read happens count decrement.
            // both remains same if write and read happens simultaneously 
            case ({(rx_valid && !rx_fifo_full), (rx_fifo_rd_en && !rx_fifo_empty)})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule

`timescale 1ns/1ps

module control_logic (
    input            clk,
    input            rst,
    input            rx_fifo_empty,
    output reg       rx_fifo_rd_en,
    input      [7:0] rx_data_decode,
    output reg       mem_wr_en,
    output reg [3:0] mem_wr_addr,
    output reg       mem_rd_en,
    output reg [3:0] mem_rd_addr,
    input            tx_fifo_full,
    output reg       tx_fifo_wr_en
);

    // States Declaration
    localparam [1:0] WAIT_CMD = 2'b00, WRITE_DATA = 2'b01, READ_DATA  = 2'b10;

    reg [1:0] state;
    reg [3:0] current_addr;
    reg [3:0] bytes_left;

    // Output Logic
    always @(*) 
    begin
        rx_fifo_rd_en = 1'b0;
        mem_wr_en     = 1'b0;
        mem_rd_en     = 1'b0;
        tx_fifo_wr_en = 1'b0;

        mem_wr_addr   = current_addr;
        mem_rd_addr   = current_addr;

        case (state)
        WAIT_CMD: 
        begin
        if (!rx_fifo_empty)
        rx_fifo_rd_en = 1'b1;
        end

        WRITE_DATA: 
            begin
            if (!rx_fifo_empty) 
            begin
                rx_fifo_rd_en = 1'b1;
                mem_wr_en     = 1'b1;
            end
            end

        READ_DATA: 
        begin
        if (!tx_fifo_full) 
        begin
            mem_rd_en     = 1'b1;
            tx_fifo_wr_en = 1'b1;
        end
        end

        default: 
        begin
        if (!rx_fifo_empty)
        rx_fifo_rd_en = 1'b1;
        end
        endcase
    end

    // State Register and Next State Logic
    always @(posedge clk or posedge rst) 
    begin
        if (rst) 
        begin
            state <= WAIT_CMD;
            current_addr <= 4'd0;
            bytes_left   <= 4'd0;
        end
        
        else begin
        case (state)
            WAIT_CMD: 
            begin
                if (!rx_fifo_empty) 
                begin
                    current_addr <= rx_data_decode[4:1];
                    bytes_left   <= {1'b0, rx_data_decode[7:5]} + 4'd1;

                if (rx_data_decode[0])
                    state <= WRITE_DATA;
                else
                    state <= READ_DATA;
                end
            end

            WRITE_DATA: 
            begin
                if (!rx_fifo_empty) 
                begin
                    if (bytes_left == 4'd1) 
                    begin
                    bytes_left <= 4'd0;
                    state <= WAIT_CMD;
                    end
                    else 
                    begin
                        bytes_left   <= bytes_left - 1'b1;
                        current_addr <= current_addr + 1'b1;
                    end
                end
            end

            READ_DATA: 
            begin
                if (!tx_fifo_full) 
                begin
                    if (bytes_left == 4'd1) 
                    begin
                    bytes_left <= 4'd0;
                    state <= WAIT_CMD;
                    end
                    else 
                    begin
                        bytes_left   <= bytes_left - 1'b1;
                        current_addr <= current_addr + 1'b1;
                    end
                end
            end

                default: 
                begin
                state <= WAIT_CMD;
                current_addr <= 4'd0;
                bytes_left   <= 4'd0;
                end
            
            endcase
        end
    end

endmodule

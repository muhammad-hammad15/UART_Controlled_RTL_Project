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

    // State declaration
    localparam [2:0] WAIT_CMD    = 3'b000,
                     DECODE_CMD  = 3'b001,
                     WRITE_FETCH = 3'b010,
                     WRITE_DATA  = 3'b011,
                     READ_DATA   = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    reg [3:0] current_addr;
    reg [3:0] next_addr;

    reg [3:0] bytes_left;
    reg [3:0] next_bytes_left;


    // 1. State / Register Block
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= WAIT_CMD;
            current_addr <= 4'd0;
            bytes_left   <= 4'd0;
        end
        else begin
            state        <= next_state;
            current_addr <= next_addr;
            bytes_left   <= next_bytes_left;
        end
    end


    // 2. Output Logic
    always @(*) begin

        rx_fifo_rd_en = 1'b0;
        mem_wr_en     = 1'b0;
        mem_rd_en     = 1'b0;
        tx_fifo_wr_en = 1'b0;

        mem_wr_addr = current_addr;
        mem_rd_addr = current_addr;

        case (state)

            WAIT_CMD: begin
                if (!rx_fifo_empty)
                    rx_fifo_rd_en = 1'b1;
            end


            DECODE_CMD: begin
                // No outputs required
            end


            WRITE_FETCH: begin
                if (!rx_fifo_empty)
                    rx_fifo_rd_en = 1'b1;
            end


            WRITE_DATA: begin
                mem_wr_en = 1'b1;
            end


            READ_DATA: begin
                if (!tx_fifo_full) begin
                    mem_rd_en     = 1'b1;
                    tx_fifo_wr_en = 1'b1;
                end
            end


            default: begin
                rx_fifo_rd_en = 1'b0;
                mem_wr_en     = 1'b0;
                mem_rd_en     = 1'b0;
                tx_fifo_wr_en = 1'b0;
            end

        endcase
    end


    // 3. Next-State Logic
    always @(*) begin

        // Default: remain in current state
        next_state      = state;
        next_addr       = current_addr;
        next_bytes_left = bytes_left;

        case (state)

            // rx_fifo_empty = 1 -> stay
            // !rx_fifo_empty    -> DECODE_CMD
            WAIT_CMD: begin

                if (!rx_fifo_empty)
                    next_state = DECODE_CMD;

            end


            // W/R = 1 -> WRITE_FETCH
            // W/R = 0 -> READ_DATA
            DECODE_CMD: begin

                next_addr =
                    rx_data_decode[4:1];

                next_bytes_left =
                    {1'b0, rx_data_decode[7:5]} + 4'd1;

                if (rx_data_decode[0])
                    next_state = WRITE_FETCH;
                else
                    next_state = READ_DATA;

            end


            // rx_fifo_empty = 1 -> stay
            // !rx_fifo_empty    -> WRITE_DATA
            WRITE_FETCH: begin

                if (!rx_fifo_empty)
                    next_state = WRITE_DATA;

            end


            // bytes_left > 1 -> WRITE_FETCH
            // bytes_left = 1 -> WAIT_CMD
            WRITE_DATA: begin

                if (bytes_left == 4'd1) begin

                    next_bytes_left = 4'd0;
                    next_state      = WAIT_CMD;

                end
                else begin

                    next_bytes_left = bytes_left - 1'b1;
                    next_addr       = current_addr + 1'b1;
                    next_state      = WRITE_FETCH;

                end

            end


            // Diagram:
            // bytes_left > 1 -> stay READ_DATA
            // bytes_left = 1 -> WAIT_CMD
            READ_DATA: begin

                // Only advance after TX FIFO accepts the byte
                if (!tx_fifo_full) begin

                    if (bytes_left == 4'd1) begin

                        next_bytes_left = 4'd0;
                        next_state      = WAIT_CMD;

                    end
                    else begin

                        next_bytes_left = bytes_left - 1'b1;
                        next_addr       = current_addr + 1'b1;
                        next_state      = READ_DATA;

                    end

                end

            end


            default: begin

                next_state      = WAIT_CMD;
                next_addr       = 4'd0;
                next_bytes_left = 4'd0;

            end

        endcase
    end

endmodule
`timescale 1ns/1ps

module uart_tx (
    input            clk,
    input            rst,
    input      [7:0] tx_data,
    input            tx_empty,
    output reg       tx_fifo_rd_en,
    output reg       serial_tx
);

    // State declaration
    localparam [1:0] IDLE  = 2'b00,
                     START = 2'b01,
                     DATA  = 2'b10,
                     STOP  = 2'b11;

    reg [1:0] state;
    reg [1:0] next_state;

    reg [7:0] shift_reg;
    reg [7:0] next_shift_reg;

    reg [2:0] bit_count;
    reg [2:0] next_bit_count;

    // 1. State and Register Block
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            shift_reg <= 8'd0;
            bit_count <= 3'd0;
        end
        else begin
            state     <= next_state;
            shift_reg <= next_shift_reg;
            bit_count <= next_bit_count;
        end
    end

    // 2. Output Logic
    always @(*) begin
        tx_fifo_rd_en = 1'b0;
        serial_tx     = 1'b1;

        case (state)
            IDLE: begin
                serial_tx = 1'b1;
                if (!tx_empty)
                    tx_fifo_rd_en = 1'b1;
            end

            START: begin
                serial_tx = 1'b0;
            end

            DATA: begin
                serial_tx = shift_reg[bit_count];
            end

            STOP: begin
                serial_tx = 1'b1;
            end

            default: begin
                tx_fifo_rd_en = 1'b0;
                serial_tx     = 1'b1;
            end
        endcase
    end

    // 3. Next State and Data Logic
    always @(*) begin
        next_state     = state;
        next_shift_reg = shift_reg;
        next_bit_count = bit_count;

        case (state)
            IDLE: begin
                if (!tx_empty)
                    next_state = START;
            end

            START: begin
                next_shift_reg = tx_data;
                next_bit_count = 3'd0;
                next_state     = DATA;
            end

            DATA: begin
                if (bit_count == 3'd7)
                    next_state = STOP;
                else
                    next_bit_count = bit_count + 1'b1;
            end

            STOP: begin
                next_state = IDLE;
            end

            default: begin
                next_state     = IDLE;
                next_shift_reg = 8'd0;
                next_bit_count = 3'd0;
            end
        endcase
    end

endmodule

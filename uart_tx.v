`timescale 1ns/1ps
module uart_tx (
    input            clk,
    input            rst,
    input      [7:0] tx_data,
    input            tx_empty,
    output reg       tx_fifo_rd_en,
    output reg       serial_tx
);
    // States
    localparam [1:0] IDLE  = 2'b00, START = 2'b01, DATA  = 2'b10, STOP  = 2'b11;

    // Internal Registers
    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [2:0] bit_count;

    // Output Logic
    always @(*) 
    begin
        tx_fifo_rd_en = 1'b0;
        serial_tx     = 1'b1;

        case (state)
            IDLE: 
            begin
                serial_tx = 1'b1;           // During IDLE serial_tx remains 1
                if (!tx_empty)              
                    tx_fifo_rd_en = 1'b1;
            end

            START: serial_tx = 1'b0;        // Start bit
            DATA:  serial_tx = shift_reg[bit_count];    // Data Transmission  
            STOP:  serial_tx = 1'b1;        // Stop bit

            default: 
            begin
                serial_tx = 1'b1;
            end
        endcase
    end

    // State Register and Next State Logic
    always @(posedge clk or posedge rst) 
    begin
        if (rst) 
        begin
            state     <= IDLE;
            shift_reg <= 8'd0;
            bit_count <= 3'd0;
        end
        
        else 
        begin
            case (state)
                IDLE: 
                begin
                    if (!tx_empty) 
                    begin
                        shift_reg <= tx_data;
                        bit_count <= 3'd0;
                        state     <= START;
                    end
                end

                START: 
                begin
                    state <= DATA;
                end

                DATA: 
                begin
                    if (bit_count == 3'd7)
                        state <= STOP;
                    else
                        bit_count <= bit_count + 1'b1;
                end

                STOP: 
                begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
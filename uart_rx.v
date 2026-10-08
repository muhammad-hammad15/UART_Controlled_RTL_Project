`timescale 1ns/1ps

module uart_rx (
    input            clk,
    input            rst,
    input            serial_rx,
    input            rx_fifo_full,
    output reg [7:0] rx_data,
    output reg       rx_valid
);

    // States
    localparam [1:0] IDLE = 2'b00, DATA = 2'b01, STOP = 2'b10;

    // Internal Registers
    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [2:0] bit_count;

    // Asyncrohonous Block
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            shift_reg <= 8'd0;
            bit_count <= 3'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end
        else begin
            rx_valid <= 1'b0;

            case (state)
                IDLE: 
                begin
                    if (serial_rx == 1'b0)          // Start bit checking
                    begin    
                        bit_count <= 3'd0;
                        state     <= DATA;
                    end
                end

                DATA: 
                begin
                    shift_reg[bit_count] <= serial_rx;  // Write data serially to shift register

                    if (bit_count == 3'd7)
                        state <= STOP;
                    else
                        bit_count <= bit_count + 1'b1;
                end

                STOP: 
                begin
                    if ((serial_rx == 1'b1) && !rx_fifo_full)   // Stop bit checking 
                    begin 
                        rx_data  <= shift_reg;
                        rx_valid <= 1'b1;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

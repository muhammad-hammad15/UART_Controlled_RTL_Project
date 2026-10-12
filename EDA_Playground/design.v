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

module fifo (
    input            clk,
    input            rst,
    input      [7:0] data_in,
    input            fifo_wr_en,
    input            fifo_rd_en,
    output reg [7:0] data_out,
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

    // Sequential block with asynchronous reset
    always @(posedge clk or posedge rst) begin
        if (rst) 
        begin
            wr_ptr   <= 3'd0;
            rd_ptr   <= 3'd0;
            count    <= 4'd0;
            data_out <= 8'd0;
        end
        else 
        begin
            if (fifo_wr_en && !fifo_full) 
            begin
                fifo_mem[wr_ptr] <= data_in;       // FIFO write and write pointer will increment
                wr_ptr <= wr_ptr + 1'b1;
            end

            if (fifo_rd_en && !fifo_empty)         // FIFO read and read pointer will increment
            begin 
                data_out <= fifo_mem[rd_ptr];
                rd_ptr   <= rd_ptr + 1'b1;    
            end

            // Update FIFO count
            case ({(fifo_wr_en && !fifo_full),(fifo_rd_en && !fifo_empty)})
                2'b10: count <= count + 1'b1; // Write only
                2'b01: count <= count - 1'b1; // Read  only
                default: count <= count;      // Else count remains same
            endcase
        end
    end

endmodule

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

    // States
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

    // 1. State/Register Block
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

    // 3. Next State Logic
    always @(*) begin
        next_state      = state;
        next_addr       = current_addr;
        next_bytes_left = bytes_left;

        case (state)
            WAIT_CMD: begin
                if (!rx_fifo_empty)
                    next_state = DECODE_CMD;
            end

            DECODE_CMD: begin
                next_addr       = rx_data_decode[4:1];
                next_bytes_left = {1'b0, rx_data_decode[7:5]} + 4'd1;

                if (rx_data_decode[0])
                    next_state = WRITE_FETCH;
                else
                    next_state = READ_DATA;
            end

            WRITE_FETCH: begin
                if (!rx_fifo_empty)
                    next_state = WRITE_DATA;
            end

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

            READ_DATA: begin
                if (!tx_fifo_full) begin
                    if (bytes_left == 4'd1) begin
                        next_bytes_left = 4'd0;
                        next_state      = WAIT_CMD;
                    end
                    else begin
                        next_bytes_left = bytes_left - 1'b1;
                        next_addr       = current_addr + 1'b1;
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

module uart_top (
    input  clk,
    input  rst,
    input  serial_rx,
    output serial_tx
);

    // RX FIFO signals
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_fifo_full;
    wire       rx_fifo_empty;
    wire       rx_fifo_rd_en;
    wire [7:0] mem_wr_data;

    // Memory signals
    wire       mem_wr_en;
    wire [3:0] mem_wr_addr;
    wire       mem_rd_en;
    wire [3:0] mem_rd_addr;
    wire [7:0] mem_rd_data;

    // TX FIFO signals
    wire       tx_fifo_wr_en;
    wire       tx_fifo_full;
    wire       tx_fifo_rd_en;
    wire       tx_fifo_empty;
    wire [7:0] tx_data;

    // UART Receiver
    uart_rx u_uart_rx (
        .clk          (clk),
        .rst          (rst),
        .serial_rx    (serial_rx),
        .rx_fifo_full (rx_fifo_full),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid)
    );

    // RX FIFO
    fifo u_rx_fifo (
        .clk        (clk),
        .rst        (rst),
        .data_in    (rx_data),
        .fifo_wr_en (rx_valid),
        .fifo_rd_en (rx_fifo_rd_en),
        .data_out   (mem_wr_data),
        .fifo_empty (rx_fifo_empty),
        .fifo_full  (rx_fifo_full)
    );

    // Control Logic
    control_logic u_control_logic (
        .clk            (clk),
        .rst            (rst),
        .rx_fifo_empty  (rx_fifo_empty),
        .rx_fifo_rd_en  (rx_fifo_rd_en),
        .rx_data_decode (mem_wr_data),
        .mem_wr_en      (mem_wr_en),
        .mem_wr_addr    (mem_wr_addr),
        .mem_rd_en      (mem_rd_en),
        .mem_rd_addr    (mem_rd_addr),
        .tx_fifo_full   (tx_fifo_full),
        .tx_fifo_wr_en  (tx_fifo_wr_en)
    );

    // Memory
    dual_port_memory u_memory (
        .clk         (clk),
        .rst         (rst),
        .mem_wr_en   (mem_wr_en),
        .mem_wr_addr (mem_wr_addr),
        .mem_wr_data (mem_wr_data),
        .mem_rd_en   (mem_rd_en),
        .mem_rd_addr (mem_rd_addr),
        .mem_rd_data (mem_rd_data)
    );

    // TX FIFO
    fifo u_tx_fifo (
        .clk        (clk),
        .rst        (rst),
        .data_in    (mem_rd_data),
        .fifo_wr_en (tx_fifo_wr_en),
        .fifo_rd_en (tx_fifo_rd_en),
        .data_out   (tx_data),
        .fifo_empty (tx_fifo_empty),
        .fifo_full  (tx_fifo_full)
    );

    // UART Transmitter
    uart_tx u_uart_tx (
        .clk           (clk),
        .rst           (rst),
        .tx_data       (tx_data),
        .tx_empty      (tx_fifo_empty),
        .tx_fifo_rd_en (tx_fifo_rd_en),
        .serial_tx     (serial_tx)
    );

endmodule

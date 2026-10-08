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
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 3'd0;
            rd_ptr <= 3'd0;
            count  <= 4'd0;
        end
        else begin
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


module uart_top (
    input  clk,
    input  rst,
    input  serial_rx,
    output serial_tx
);
    // RX_FIFO Signals 
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_fifo_full;
    wire       rx_fifo_empty;
    wire       rx_fifo_rd_en;
    wire [7:0] mem_wr_data;

    // Memory Signals
    wire       mem_wr_en;
    wire [3:0] mem_wr_addr;
    wire       mem_rd_en;
    wire [3:0] mem_rd_addr;
    wire [7:0] mem_rd_data;

    // TX_FIFO Signals
    wire       tx_fifo_wr_en;
    wire       tx_fifo_full;
    wire       tx_fifo_rd_en;
    wire       tx_empty;
    wire [7:0] tx_data;

    uart_rx u_uart_rx (
        .clk          (clk),
        .rst          (rst),
        .serial_rx    (serial_rx),
        .rx_fifo_full (rx_fifo_full),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid)
    );

    rx_fifo u_rx_fifo (
        .clk           (clk),
        .rst           (rst),
        .rx_data       (rx_data),
        .rx_valid      (rx_valid),
        .rx_fifo_rd_en (rx_fifo_rd_en),
        .mem_wr_data   (mem_wr_data),
        .rx_fifo_empty (rx_fifo_empty),
        .rx_fifo_full  (rx_fifo_full)
    );

    control_logic u_control_logic (
        .clk           (clk),
        .rst           (rst),
        .rx_fifo_empty (rx_fifo_empty),
        .rx_fifo_rd_en (rx_fifo_rd_en),
        .rx_data_decode (mem_wr_data),
        .mem_wr_en     (mem_wr_en),
        .mem_wr_addr   (mem_wr_addr),
        .mem_rd_en     (mem_rd_en),
        .mem_rd_addr   (mem_rd_addr),
        .tx_fifo_full  (tx_fifo_full),
        .tx_fifo_wr_en (tx_fifo_wr_en)
    );

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

    tx_fifo u_tx_fifo (
        .clk           (clk),
        .rst           (rst),
        .mem_rd_data   (mem_rd_data),
        .tx_fifo_wr_en (tx_fifo_wr_en),
        .tx_fifo_rd_en (tx_fifo_rd_en),
        .tx_data       (tx_data),
        .tx_empty      (tx_empty),
        .tx_fifo_full  (tx_fifo_full)
    );

    uart_tx u_uart_tx (
        .clk           (clk),
        .rst           (rst),
        .tx_data       (tx_data),
        .tx_empty      (tx_empty),
        .tx_fifo_rd_en (tx_fifo_rd_en),
        .serial_tx     (serial_tx)
    );

endmodule
module UART_Driver #(
    parameter N_BYTES  = 2,
    parameter CLK_FREC = 27000000,
    parameter BAUDRATE = 9600
)(
    input  clk, rst,
    input  pin_rx,
    output pin_tx,
    output [(N_BYTES*8)-1:0] rx_data,
    output                   rx_valid,
    input                    rx_ready,
    input  [(N_BYTES*8)-1:0] tx_data,
    input                    tx_valid,
    output                   tx_ready
);

    wire [7:0] u2b_data, b2u_data;
    wire u2b_valid, u2b_ready;
    wire b2u_valid, b2u_ready;

    UART_V1 #(
        .clk_frec_fpga(CLK_FREC), 
        .tasa_baudios(BAUDRATE)
    ) phy (
        .clk(clk), .rst(rst),
        .RX(pin_rx), .TX(pin_tx),
        .datos_recibido(u2b_data), .hecho_rx(u2b_valid), .next_ready(u2b_ready),
        .datos_enviar(b2u_data),   .datos_validos(b2u_valid), .tx_ready(b2u_ready),
        .hecho_tx()
    );

    UART_MultiByte_Bridge #(
        .N_BYTES(N_BYTES)
    ) bridge (
        .clk(clk), .rst(rst),
        .u_rx_data(u2b_data), .u_rx_valid(u2b_valid), .u_rx_ready(u2b_ready),
        .u_tx_data(b2u_data), .u_tx_valid(b2u_valid), .u_tx_ready(b2u_ready),
        .w_rx_data(rx_data), .w_rx_valid(rx_valid), .w_rx_ready(rx_ready),
        .w_tx_data(tx_data), .w_tx_valid(tx_valid), .w_tx_ready(tx_ready)
    );

endmodule

// ===============================================================================
// MODULO: UART_MultiByte_Bridge
// ===============================================================================
module UART_MultiByte_Bridge #(
    parameter N_BYTES = 2
)(
    input  clk, rst,
    input  [7:0] u_rx_data, input u_rx_valid, output reg u_rx_ready,
    output reg [7:0] u_tx_data, output reg u_tx_valid, input  u_tx_ready,
    output [(N_BYTES*8)-1:0] w_rx_data, output reg w_rx_valid, input w_rx_ready,
    input  [(N_BYTES*8)-1:0] w_tx_data, input  w_tx_valid, output reg w_tx_ready
);
    reg [7:0] rx_cnt; 
    reg [(N_BYTES*8)-1:0] rx_buf;

    assign w_rx_data = rx_buf;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_cnt <= 8'd0; w_rx_valid <= 1'b0; u_rx_ready <= 1'b0;
        end else begin
            u_rx_ready <= 1'b1; 
            
            if (w_rx_valid && w_rx_ready) w_rx_valid <= 1'b0;

            if (u_rx_valid && u_rx_ready) begin
                rx_buf[rx_cnt*8 +: 8] <= u_rx_data;
                if (rx_cnt == N_BYTES - 1) begin
                    rx_cnt <= 8'd0;
                    w_rx_valid <= 1'b1;
                    u_rx_ready <= 1'b0;
                end else begin
                    rx_cnt <= rx_cnt + 8'd1;
                end
            end
        end
    end

    reg [7:0] tx_cnt;
    reg [(N_BYTES*8)-1:0] tx_buf;
    reg tx_active;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_active <= 1'b0; tx_cnt <= 8'd0; u_tx_valid <= 1'b0; w_tx_ready <= 1'b0;
        end else begin
            if (!tx_active) begin
                u_tx_valid <= 1'b0; 
                tx_cnt <= 8'd0; 
                w_tx_ready <= 1'b1;

                if (w_tx_valid && w_tx_ready) begin
                    tx_buf <= w_tx_data;
                    w_tx_ready <= 1'b0;
                    tx_active <= 1'b1;
                end
            end else begin
                u_tx_data <= tx_buf[tx_cnt*8 +: 8];
                u_tx_valid <= 1'b1;

                if (u_tx_valid && u_tx_ready) begin
                    u_tx_valid <= 1'b0;
                    if (tx_cnt == N_BYTES - 1) begin
                        tx_active <= 1'b0;
                    end else begin
                        tx_cnt <= tx_cnt + 8'd1;
                    end
                end
            end
        end
    end
endmodule

// ===============================================================================
// MODULO: UART_V1
// ===============================================================================
module UART_V1 #(
    parameter clk_frec_fpga = 27000000,
    parameter tasa_baudios  = 9600
)(
    input  clk, rst,
    input  RX,
    input  [7:0] datos_enviar,
    input  datos_validos, 
    output [7:0] datos_recibido,
    output TX,
    output tx_ready,
    output hecho_rx,
    input  next_ready,
    output hecho_tx
);

    wire pulso;
    wire pulsox16;
    wire habilitar_gen;

    assign habilitar_gen = 1'b1; 

    UART_GenBaudio #(
        .clk_frec_fpga (clk_frec_fpga),
        .tasa_baudios  (tasa_baudios)
    ) GenBaudio1 (
        .clk      (clk),
        .rst      (rst),
        .habilitar(habilitar_gen),
        .pulso    (pulso),
        .pulsox16 (pulsox16)
    );

    UART_RX UART_RX1 (
        .clk            (clk),
        .rst            (rst),
        .pulsox16       (pulsox16),
        .RX             (RX),
        .next_ready     (next_ready),
        .datos_recibido (datos_recibido),
        .hecho_rx       (hecho_rx)
    );

    UART_TX UART_TX1 (
        .clk           (clk),
        .rst           (rst),
        .pulso         (pulso),
        .datos_validos (datos_validos),
        .datos_enviar  (datos_enviar),
        .TX            (TX),
        .tx_ready      (tx_ready),
        .hecho_tx      (hecho_tx)
    );

endmodule

// ===============================================================================
// MODULO: UART_GenBaudio
// ===============================================================================
module UART_GenBaudio #(
    parameter clk_frec_fpga = 27000000,
    parameter tasa_baudios = 9600
)(
    input clk,
    input rst,
    input habilitar,
    output reg pulso,
    output reg pulsox16
);

    localparam clk_contador = (clk_frec_fpga/(tasa_baudios*16));

    reg [15:0] contador;
    reg [3:0]  subcnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            contador <= 16'b0;
            subcnt   <= 4'b0;
            pulso    <= 1'b0;
            pulsox16 <= 1'b0;
        end 
        else if (habilitar) begin
            pulso    <= 1'b0;
            pulsox16 <= 1'b0;

            if (contador == clk_contador - 1) begin
                contador <= 16'b0;
                pulsox16 <= 1'b1;
                if (subcnt == 4'd15) begin
                    subcnt <= 4'b0;
                    pulso <= 1'b1;
                end
                else begin
                    subcnt <= subcnt + 4'b1;
                end 
            end 
            else begin
                contador <= contador + 16'b1;
            end
        end
        else begin
            contador <= 16'b0;
            subcnt   <= 4'b0;
            pulso    <= 1'b0;
            pulsox16 <= 1'b0;
        end 
    end

endmodule

// ===============================================================================
// MODULO: UART_RX
// ===============================================================================
module UART_RX (
    input  clk, rst,
    input  pulsox16,
    input  RX,
    input  next_ready,
    output reg [7:0] datos_recibido,
    output reg hecho_rx
);

    localparam IDLE       = 3'd0;
    localparam START      = 3'd1;
    localparam DATA       = 3'd2;
    localparam STOP       = 3'd3;
    localparam WAIT_READY = 3'd4;

    reg [2:0] estado;
    reg [2:0] contador_NroBit;
    reg [3:0] contador_pulsos;
    reg [7:0] shift_reg;
    reg rx_sync;
    reg rx_r;

    always @(posedge clk) begin
        rx_r    <= RX;
        rx_sync <= rx_r;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            estado <= IDLE;
            contador_NroBit <= 3'd0;
            datos_recibido <= 8'b0;
            hecho_rx <= 1'b0;
            contador_pulsos <= 4'd0;
        end
        else begin
            case (estado)
                IDLE: begin
                    hecho_rx <= 1'b0;
                    contador_pulsos <= 4'd0;
                    contador_NroBit <= 3'd0;
                    if (rx_sync == 1'b0) begin 
                        estado <= START;
                    end
                end

                START: if (pulsox16) begin
                    if (contador_pulsos == 4'd7) begin
                        if (rx_sync == 1'b1) estado <= IDLE; 
                        else contador_pulsos <= contador_pulsos + 4'd1;
                    end
                    else if (contador_pulsos == 4'd15) begin
                        contador_pulsos <= 4'd0;
                        estado <= DATA;
                    end
                    else contador_pulsos <= contador_pulsos + 4'd1;
                end

                DATA: if (pulsox16) begin
                    if (contador_pulsos == 4'd7) begin
                        shift_reg[contador_NroBit] <= rx_sync;
                        contador_pulsos <= contador_pulsos + 4'd1;
                    end
                    else if (contador_pulsos == 4'd15) begin
                        contador_pulsos <= 4'd0;
                        if (contador_NroBit == 3'd7) estado <= STOP;
                        else contador_NroBit <= contador_NroBit + 3'd1;
                    end
                    else contador_pulsos <= contador_pulsos + 4'd1;
                end

                STOP: if (pulsox16) begin
                    if (contador_pulsos == 4'd7) begin
                        if (rx_sync == 1'b1) begin 
                            datos_recibido <= shift_reg;
                        end
                        contador_pulsos <= contador_pulsos + 4'd1;
                    end
                    else if (contador_pulsos == 4'd15) begin
                        contador_pulsos <= 4'd0;
                        hecho_rx <= 1'b1; 
                        estado <= WAIT_READY; 
                    end
                    else contador_pulsos <= contador_pulsos + 4'd1;
                end

                WAIT_READY: begin
                    if (next_ready) begin
                        hecho_rx <= 1'b0; 
                        estado <= IDLE;
                    end
                end
                default: estado <= IDLE;
            endcase
        end
    end
endmodule

// ===============================================================================
// MODULO: UART_TX
// ===============================================================================
module UART_TX (
    input  clk, rst,
    input  pulso,
    input  datos_validos,
    input  [7:0] datos_enviar,
    output reg TX,
    output tx_ready,
    output reg hecho_tx
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] estado;
    reg [2:0] contador_NroBit;
    reg [7:0] datosTX;

    assign tx_ready = (estado == IDLE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            estado <= IDLE;
            contador_NroBit <= 3'd0;
            TX <= 1'b1;
            hecho_tx <= 1'b0;
        end
        else begin
            case (estado)
                IDLE: begin
                    hecho_tx <= 1'b0;
                    TX <= 1'b1;
                    if (datos_validos) begin
                        datosTX <= datos_enviar;
                        estado <= START;
                    end
                end

                START: if (pulso) begin
                    TX <= 1'b0; 
                    contador_NroBit <= 3'd0;
                    estado <= DATA;
                end

                DATA: if (pulso) begin
                    TX <= datosTX[contador_NroBit];
                    if (contador_NroBit == 3'd7)
                        estado <= STOP;
                    else
                        contador_NroBit <= contador_NroBit + 3'd1;
                end 

                STOP: if (pulso) begin
                    TX <= 1'b1;
                    hecho_tx <= 1'b1;
                    estado <= IDLE;
                end
                
                default: estado <= IDLE;
            endcase
        end
    end
endmodule
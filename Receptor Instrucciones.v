module Receptor_Instrucciones #(
    // ¡Aquí cambias la frecuencia fácilmente!
    parameter FRECUENCIA_RELOJ = 27000000, 
    parameter BAUDRATE         = 9600
)(
    input  wire clk,
    input  wire rst,      // Botón de reset general del sistema
    input  wire pin_rx,   // Pin físico conectado al TX del Pi Pico/PC
    output wire pin_tx,   // Pin físico (opcional, por si luego quieres enviar datos)
    
    // ==========================================
    // SALIDAS CONTINUAS PARA TU COMPAÑERO
    // ==========================================
    output wire [7:0] out_horas,
    output wire [7:0] out_minutos,
    output wire [7:0] out_segundos,
    output wire [3:0] out_canales,
    output wire [3:0] out_estados,
    output wire       out_reset_sys,
    output wire       out_iniciar_reloj
);

    // Cables internos para conectar UART con Decodificador
    wire [7:0] uart_rx_data;
    wire       uart_rx_valid;
    wire       uart_rx_ready = 1'b1; // Siempre listos para recibir
    
    // Cables internos para conectar Decodificador con Registros
    wire       update_flag;
    wire [7:0] cmd_bus;
    wire [7:0] p1_bus, p2_bus, p3_bus;

    // 1. Instancia del UART (El módulo que tú me diste)
    UART_Driver #(
        .N_BYTES(1), 
        .CLK_FREC(FRECUENCIA_RELOJ),
        .BAUDRATE(BAUDRATE)
    ) mi_uart (
        .clk     (clk),
        .rst     (rst),
        .pin_rx  (pin_rx),
        .pin_tx  (pin_tx),
        .rx_data (uart_rx_data),
        .rx_valid(uart_rx_valid),
        .rx_ready(uart_rx_ready),
        .tx_data (8'd0),   // No transmitimos nada por ahora
        .tx_valid(1'b0),
        .tx_ready()
    );

    // 2. Instancia del Decodificador (El Parser)
    Deco_Instrucciones decodificador (
        .clk          (clk),
        .rst          (rst),
        .rx_valid     (uart_rx_valid),
        .rx_data      (uart_rx_data),
        .update_flag  (update_flag),
        .cmd_out      (cmd_bus),
        .p1_out       (p1_bus),
        .p2_out       (p2_bus),
        .p3_out       (p3_bus)
    );

    // 3. Instancia del Banco de Registros (La Memoria)
    Reg_Instrucciones registros (
        .clk          (clk),
        .rst          (rst),
        .update_flag  (update_flag),
        .cmd_in       (cmd_bus),
        .p1_in        (p1_bus),
        .p2_in        (p2_bus),
        .p3_in        (p3_bus),
        .reg_horas    (out_horas),
        .reg_minutos  (out_minutos),
        .reg_segundos (out_segundos),
        .reg_canales  (out_canales),
        .reg_estados  (out_estados),
        .reg_reset_sys(out_reset_sys),
        .reg_iniciar  (out_iniciar_reloj)
    );

endmodule
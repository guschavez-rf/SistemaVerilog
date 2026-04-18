module Deco_Instrucciones (
    input  wire clk,
    input  wire rst,
    input  wire rx_valid,      // Indica que llegó un byte nuevo
    input  wire [7:0] rx_data, // El byte que llegó
    
    // Salidas hacia los registros
    output reg       update_flag,
    output reg [7:0] cmd_out,
    output reg [7:0] p1_out,
    output reg [7:0] p2_out,
    output reg [7:0] p3_out
);

    // Definición de los estados
    localparam ESPERAR_HEADER = 3'd0;
    localparam RECIBIR_CMD    = 3'd1;
    localparam RECIBIR_P1     = 3'd2;
    localparam RECIBIR_P2     = 3'd3;
    localparam RECIBIR_P3     = 3'd4;

    reg [2:0] estado_actual;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            estado_actual <= ESPERAR_HEADER;
            update_flag   <= 1'b0;
            cmd_out       <= 8'd0;
            p1_out        <= 8'd0;
            p2_out        <= 8'd0;
            p3_out        <= 8'd0;
        end else begin
            // Por defecto, la bandera de actualización dura solo 1 ciclo de reloj
            update_flag <= 1'b0;

            if (rx_valid) begin
                case (estado_actual)
                    ESPERAR_HEADER: begin
                        if (rx_data == 8'hAA) begin
                            estado_actual <= RECIBIR_CMD;
                        end
                    end
                    
                    RECIBIR_CMD: begin
                        cmd_out <= rx_data;
                        estado_actual <= RECIBIR_P1;
                    end
                    
                    RECIBIR_P1: begin
                        p1_out <= rx_data;
                        estado_actual <= RECIBIR_P2;
                    end
                    
                    RECIBIR_P2: begin
                        p2_out <= rx_data;
                        estado_actual <= RECIBIR_P3;
                    end
                    
                    RECIBIR_P3: begin
                        p3_out <= rx_data;
                        update_flag <= 1'b1; // ¡Trama completa! Avisar a memoria
                        estado_actual <= ESPERAR_HEADER; // Volver a empezar
                    end
                    
                    default: estado_actual <= ESPERAR_HEADER;
                endcase
            end
        end
    end
endmodule
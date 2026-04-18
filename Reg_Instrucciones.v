module Reg_Instrucciones (
    input wire clk,
    input wire rst,
    input wire update_flag,   // Pulso proveniente del Decodificador
    input wire [7:0] cmd_in,
    input wire [7:0] p1_in,
    input wire [7:0] p2_in,
    input wire [7:0] p3_in,
    
    // Los registros de estado persistentes
    output reg [7:0] reg_horas,
    output reg [7:0] reg_minutos,
    output reg [7:0] reg_segundos,
    output reg [3:0] reg_canales,
    output reg [3:0] reg_estados,
    output reg       reg_reset_sys,
    output reg       reg_iniciar
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Estado inicial de la memoria al reiniciar la FPGA
            reg_horas     <= 8'd0;
            reg_minutos   <= 8'd0;
            reg_segundos  <= 8'd0;
            reg_canales   <= 4'b0000;
            reg_estados   <= 4'b0000;
            reg_reset_sys <= 1'b0;
            reg_iniciar   <= 1'b0;
        end else if (update_flag) begin
            // Solo actualizamos cuando la trama de 5 bytes es válida
            case (cmd_in)
                8'h48: begin // Letra 'H' - Configurar Hora
                    reg_horas    <= p1_in;
                    reg_minutos  <= p2_in;
                    reg_segundos <= p3_in;
                end
                
                8'h52: begin // Letra 'R' - Activar Reset Persistente
                    reg_reset_sys <= 1'b1;
                end
                
                8'h53: begin // Letra 'S' - Desactivar Reset (Set)
                    reg_reset_sys <= 1'b0;
                end
                
                8'h49: begin // Letra 'I' - Iniciar Reloj
                    reg_iniciar <= 1'b1;
                end
                
                8'h51: begin // Letra 'Q' - Activar un canal específico (1, 2, 3 o 4)
                    // Si recibimos 1, encendemos el bit 0. Si es 2, el bit 1, etc.
                    if (p1_in >= 8'd1 && p1_in <= 8'd4) begin
                        reg_canales[p1_in - 1] <= 1'b1;
                    end
                end
                
                8'h54: begin // Letra 'T' - Enviar datos a todos los canales
                    reg_canales <= 4'b1111;
                end
                
                8'h45: begin // Letra 'E' - Guardar estados
                    reg_estados <= p1_in[3:0]; // Tomamos solo los 4 bits bajos
                end
                
                default: begin
                    // Comando no reconocido, no hacemos nada
                end
            endcase
        end
    end
endmodule
`timescale 1ns/1ps

module tb_Receptor_Instrucciones();
    reg clk = 0;
    reg rst = 1;
    reg pin_rx = 1;
    
    // Salidas del Banco de Registros
    wire [7:0] h, m, s, canales, estados;
    wire rst_sys, init;

    // Instancia del sistema (Asegúrate de que el nombre del archivo coincida)
    Receptor_Instrucciones #(
        .FRECUENCIA_RELOJ(27000000),
        .BAUDRATE(115200) 
    ) uut (
        .clk(clk), .rst(rst), .pin_rx(pin_rx), .pin_tx(),
        .out_horas(h), .out_minutos(m), .out_segundos(s),
        .out_canales(canales), .out_estados(estados),
        .out_reset_sys(rst_sys), .out_iniciar_reloj(init)
    );

    // Reloj de 27MHz
    always #18.5 clk = ~clk;

    // Tarea para simular el envío UART (LSB first)
    task enviar_byte(input [7:0] dato);
        integer i;
        begin
            pin_rx = 0; // Bit de Inicio
            #(8680);    // Tiempo de bit para 115200 baudios
            for (i = 0; i < 8; i = i + 1) begin
                pin_rx = dato[i];
                #(8680);
            end
            pin_rx = 1; // Bit de Parada
            #(8680);
        end
    endtask

    initial begin
        $dumpfile("Receptor_Instrucciones.vcd");
        $dumpvars(0, tb_Receptor_Instrucciones);

        // Reset inicial del sistema
        #100 rst = 0; 
        #200;

        // --- INSTRUCCIÓN 1: CONFIGURAR HORA 08:30:15 ---
        // Paquete: AA 48 08 1E 0F
        enviar_byte(8'hAA); 
        enviar_byte(8'h48); // 'H'
        enviar_byte(8'h08); // 8 horas
        enviar_byte(8'h1E); // 30 minutos
        enviar_byte(8'h0F); // 15 segundos
        #20000; // Espera para observar estabilidad

        // --- INSTRUCCIÓN 2: ACTIVAR RESET DEL SISTEMA ---
        // Paquete: AA 52 00 00 00
        enviar_byte(8'hAA);
        enviar_byte(8'h52); // 'R'
        enviar_byte(8'h00);
        enviar_byte(8'h00);
        enviar_byte(8'h00);
        #20000;

        // --- INSTRUCCIÓN 3: ACTIVAR CANAL 3 ---
        // Paquete: AA 51 03 00 00
        enviar_byte(8'hAA);
        enviar_byte(8'h51); // 'Q'
        enviar_byte(8'h03); // Canal 3
        enviar_byte(8'h00);
        enviar_byte(8'h00);

        #50000;
        $display("Simulación finalizada.");
        $finish;
    end
endmodule
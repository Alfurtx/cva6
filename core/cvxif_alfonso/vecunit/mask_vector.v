`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.01.2024 16:24:35
// Design Name: 
// Module Name: mask_vector
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mask_vector #(
        parameter DATA_WIDTH = 1, // Como sólo se copia 1 bit, la anchura del dato es de 1
        parameter VALID = 1, 
        parameter MVL = 16 
    ) (
        input clk,                          // Señal de reloj
        input rst,                          // Señal de reset
        input [bitwidth(MVL):0] VLR,        // Entrada del VLR
        input w_signal,                     // Señal de escritura
        input [DATA_WIDTH+VALID-1:0] wd_i,  // Entrada de datos
        output [MVL-1:0] rd_o,              // Salida de datos
        output reg busy_write,              // Salida registrada que indica que se está escribiendo
                                            // o se está esperando para escribir
        output reg mask_ready               // Salida registrada que indica que la máscara está lista
    );
    
    localparam valid_pos = DATA_WIDTH;  // Parámetro de la posición del bit valid
    
    reg [bitwidth(MVL):0] vlr_w;        // Registro para almacenar el vlr
    reg [bitwidth(MVL):0] counter;      // Contador
    reg [MVL-1:0] mask;                 // Registro para almacenar la máscara
    
    assign rd_o = mask;                 // La máscara se envía por el puerto de salida
    
    
    // Bloque always para controlar la copia de la máscara
    // Señal de reset -> todos los registros y la máscara a 0
    // Señal de escritura -> mask_ready a 0, capturar vlr entrante,
    // activar busy_write e iniciar el contador
    // En cada ciclo mientras busy esté activo, el dato entrante sea válido
    // y el contador sea menor o igual al vlr:
    // Si el contador == vlr, se ha copiado ya toda la máscara:
    // mask_ready a 1, busy a 0 y reiniciar el resto de contadores
    // Si el contador < vlr, incrementar el contador
    always @(posedge clk) begin
    	if (rst) begin
    		mask_ready <= 1;
    		vlr_w <= 0;
    		busy_write <=0;
    		counter <= 0;
    	end else if (w_signal) begin
            mask_ready <= 0;
            vlr_w <= VLR;
            busy_write <= 1'b1;
			counter <= 1;
        end else if (busy_write & wd_i[DATA_WIDTH] & (counter <= vlr_w) ) begin
            if(counter == vlr_w ) begin
                mask_ready <= 1;
                counter <= 0;
                busy_write <= 0;
                vlr_w <= 0;
            end else begin
                counter <= counter + 1;
            end
        end
    end
    
    always @(posedge clk) begin
    	if (rst) begin
    		mask <= 0;
    	end else if(busy_write & wd_i[DATA_WIDTH] & (vlr_w > 0)) begin
    		mask[(counter-1'b1)] <= wd_i[0];
    	end
    end

		//
        // Gets the log2 of a given number
        //
        // Params:
        // value, the value to obtain its log2
        //
        // Returns:
        // The log2 of the value
        //
        function integer log2(integer value);
        begin
        value = value-1;
        for (log2=0; value>0; log2=log2+1)
        value = value>>1;
        end
        endfunction
        
        //
        // Gets the number of bits required to encode a value
        //
        // Params:
        // value, the value to encode
        //
        // Returns:
        // The number of bits required to encode value input param
        //
        function integer bitwidth(integer value);
        begin                          
        if (value <= 1)
        bitwidth = 1;
        else
        bitwidth = log2(value);
        end
        endfunction
    
endmodule

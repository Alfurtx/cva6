`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.12.2023 11:04:54
// Design Name: 
// Module Name: fifo_mem
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


module fifo_mem #(parameter SIZE = 10, WIDTH = 10) (
        input clk_i,                            // Señal de reloj
        input rst,                              // Señal de reset
        input w_en,                             // Señal de escritura
        input  [bitwidth(SIZE)-1:0] r_address,  // Direccion de lectura
        input  [bitwidth(SIZE)-1:0] w_address,  // Direccion de escritura
        input  [WIDTH-1:0] w_data,              // Dato entrante a escribir
        output [WIDTH-1:0] r_output             // Dato saliente (el apuntado por la direccion de lectura)
    );
    
    reg [WIDTH-1:0] fifo_mem [0:SIZE-1];        // Memoria (Cola)
    
    assign r_output = fifo_mem[r_address];      // Lectura siempre activa a donde apunte la dirección de lectura
    
    integer rst_f;
    
    // Bloque always para gestionar la escritura en la memoria (cola)
    // Señal de reset -> se reinicia el contenido de la cola
    // Señal de escritura -> se escribe el dato entrante en la posición apuntada por la direccion de escritura
    always @(posedge clk_i) begin
    	if (rst) begin
    		for (rst_f = 0; rst_f < SIZE; rst_f = rst_f + 1) begin
    			fifo_mem[rst_f] <= 'b0;
    		end
    	end else if (w_en) begin
            fifo_mem[w_address] <= w_data;
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

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.02.2024 13:05:58
// Design Name: 
// Module Name: vl_reg
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


module vl_reg #(parameter MVL = 16) (
		input clk,                        // Señal de reloj
		input rst,                        // Señal de reset
		input we,                         // Señal de escritura
		input [bitwidth(MVL):0] value_in, // Dato entrante a escribir
		output reg [bitwidth(MVL):0] vlr  // Registro que almacena el vlr / salida de dato
    );
    
    // Bloque always para gestionar la escritura
    // Señal de reset -> VLR a valor por defecto: 32
    // Señal de escritura -> VLR al valor que esté entrando por el puerto value_in
    always @(posedge clk) begin
    	if (rst) begin
    		// Nota (alfonso): no deberia de ser esto 6'b100000? para hacer 32 el valor por defecto
    		vlr <= 5'b10000;
    	end else if (we) begin
    		vlr <= value_in;
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

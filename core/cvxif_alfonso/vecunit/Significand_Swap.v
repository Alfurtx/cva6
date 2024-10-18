`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.10.2023 09:14:15
// Design Name: 
// Module Name: Significand_Swap
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


module Significand_Swap(
//En este módulo pondremos como mantisa A aquella que sea mayor y como mantisa B aquella que sea menor
input [22:0] significand_a, // Mantissa a antes del cambio
input [22:0] significand_b, // Mantissa b antes del cambio
input swap,                // Nos llega desde la resta de exponentes, si es 1 hay que swapear las mantisas, sino no
input  [1:0] hidden,       // Nos llega desde la resta de exponentes, si es 1 es que el hidden bit es 1, sino es 0
output [23:0] significand_A, // Mantissa a después del cambio
output [23:0] significand_B // Mantissa b después del cambio
    );
assign significand_A = hidden[1]?  swap? {1'b1,significand_b} : {1'b1,significand_a} 
 : swap? {1'b0,significand_b} : {1'b0,significand_a}; 
assign significand_B =  hidden[0]?  swap? {1'b1,significand_a} : {1'b1,significand_b} 
 : swap? {1'b0,significand_a} : {1'b0,significand_b};     
endmodule

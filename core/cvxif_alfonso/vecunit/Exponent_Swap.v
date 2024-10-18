`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.10.2023 09:48:19
// Design Name: 
// Module Name: Exponent_Swap
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


module Exponent_Swap(
input [7:0] exponent_a,  //Exponente a antes del cambio
input [7:0] exponent_b,  //Exponente b antes del cambio
input swap,                      // Nos llega desde la resta de exponentes, si es 1 hay que swapear las mantisas, sino no
output [7:0] exponent_A //Exponente a después del cambio
//output equals
    );
//assign equals = (exponent_a == exponent_b) ? 1'b1: 1'b0; 
assign exponent_A = swap ? exponent_b : exponent_a;
assign exponent_B = swap ? exponent_a : exponent_b;
endmodule
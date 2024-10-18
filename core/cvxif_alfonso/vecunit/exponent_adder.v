`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.02.2024 14:49:29
// Design Name: 
// Module Name: FastAdd
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


module exponent_adder (
    input [7:0] EA,
    input [7:0] EB,
    output [7:0] exp_sum
);

assign exp_sum = EA +EB;
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 30.01.2024 11:00:33
// Design Name: 
// Module Name: Exponent_Check
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


module Exponent_Check(
input [7:0] EA,EB,
output flag_1_a, flag_1_b, flag_0_a, flag_0_b
    );
    
    assign flag_1_a = (&EA); // Si flag a 1, es infinito o NAN, sino no hay nada
    assign flag_1_b = (&EB); // Si flag a 1, es infinito o NAN, sino no hay nada
    assign flag_0_a = ~(|EA); // SI flag a 1 es denormalized, sino no hay nada 
    assign flag_0_b = ~(|EB); // SI flag a 1 es denormalized, sino no hay nada 
endmodule

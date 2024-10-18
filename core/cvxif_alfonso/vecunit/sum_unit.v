`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.02.2024 14:38:56
// Design Name: 
// Module Name: sum_unit
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


module sum_unit#( // Este modulo se encargará de realizar la suma de salida y el último carry
    parameter BITS = 4
)
(

input wire  [BITS - 1 : 0] C,P, 
output wire [BITS - 1 : 0] S_o
 );   
     // ACLARACIÓN PARA PEPE
     // P[ BITS -1 : 0] = A[ BITS - 1 : 0] ^ B[ BITS - 1 : 0]  
     assign  S_o[BITS - 1:0] = P[BITS - 1 : 0]  ^ C[BITS - 1:0];
endmodule

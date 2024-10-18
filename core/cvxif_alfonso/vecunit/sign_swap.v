`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.12.2023 11:37:45
// Design Name: 
// Module Name: Control_2
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


module Sign_Swap(
input SA,
input SB,
input swap,
output SA_o,
output SB_o
    );
assign {SA_o,SB_o} = swap ? {SB,SA} : {SA,SB};
endmodule

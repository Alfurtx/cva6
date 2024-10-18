`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.11.2023 08:28:48
// Design Name: 
// Module Name: barrel_Shifter
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
// 23 nov 2023 , actualizamos con caso 5 de la diapo

module barrel_Shifter(
    input [22:0] significand,
    input [4:0] shift,
    input g, 
    output [22:0] normalized_Significand,
    output [4:0] shift_o
);
wire[22:0] significand_g;
// Caso 2: Añadimos el bit de guarda a la derecha   
assign significand_g= {significand[21:0],g};
assign shift_o = shift;
assign normalized_Significand= (|shift) ?  significand_g << (shift -1) : significand;

endmodule

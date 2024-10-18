`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.11.2023 10:44:10
// Design Name: 
// Module Name: Priority_Encoder
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
// 21/NOV/23  ARREGLADO PRIORITY ECONDER, no tenía en cuenta el caso default
module Priority_Encoder
(
    input [7:0] exponent,
    input [24:0] significand,
    output [4:0] shift,
    output  [7:0] normalized_Exponent
    );
    reg [4:0] position; 
    integer i;
    always @* begin
        position = 24; //Valor por defecto si toda la mantissa son todo 0
        for (i=0 ;i<24 ; i=i+1)
            if (significand[i])
                position = (23-i);
        end
assign shift = significand[24] ? position : 5'b0;
assign normalized_Exponent = (exponent - shift);
endmodule

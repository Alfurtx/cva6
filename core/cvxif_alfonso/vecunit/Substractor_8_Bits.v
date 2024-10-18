`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.10.2023 16:44:21
// Design Name: 
// Module Name: Substractor_8_Bits
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
module Substractor_8_Bits(
input [30:0] operand_a, //Exponente A
input [30:0] operand_b, //Exponente B
output [7:0] exponent_diff, //Diferencias de exponentes
output swap,                 //Nos permite saber si swapear mantissas en otro módulo
output [1:0] hidden,          //Nos permite saber si el hidden bit de la mantissa es 0 o 1 
output equals  // Si los operandos son iguales, para poner el exponente a 0
    );
 //Es pot fer amb logica de ands i ors 23/1/24 
 assign hidden = {|operand_a[30:23] , |operand_b[30:23]}; 
//    assign hidden = 
//    ((|exponent_a) & (|exponent_b)) ? {1'b1,1'b1} :
//     ((|exponent_a) & ~(|exponent_b)) ? {1'b1,1'b0} :
//       (~(|exponent_a) & (|exponent_b)) ? {1'b0,1'b1} :
//         2'b0;  
    //Sacamos la diferencia de exponentes en valor absoluto y damos valor a swap
    assign {exponent_diff,swap} = (operand_a > operand_b|| operand_a ==operand_b) ? {operand_a[30:23] - operand_b[30:23],1'b0} : {operand_b[30:23] - operand_a[30:23],1'b1};
    assign equals = operand_a == operand_b;  
       
endmodule
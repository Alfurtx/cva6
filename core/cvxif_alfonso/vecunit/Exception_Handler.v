`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.02.2024 12:20:04
// Design Name: 
// Module Name: Exception_Handler
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

// tiene que entrar el resultado, la mascara y todas las flag aquí dentro
module Exception_Handler(
input valid,
input mask,
input SA,
input [7:0] EA,
input [23:0] MA,
input [30:0] Result, // Este es el resultado de la operación cuando no hay excepción
input Den_Flag, // Flag de operación mixta
input dend_flag, //Flag de operacion solo con subnormales
input Inf_Control_Flag,  // Flag de infinito del control
input Inf_Pr_Flag, // Flag de infinito del pre rounder
input Inf_R_Flag, // Flag de infinito de rounder
input equals,
input operation_sign,
output [33:0] Final_Result // Valid, Mask, Result[31:0]
    );
    
    assign Final_Result = 
    (Den_Flag && ~dend_flag)? {valid,mask,SA,EA,MA[22:0]} :
    // Caso Infinito o Nan. Ponemos la máscara a 0 para que no se escriba el dato
    (Inf_Control_Flag | Inf_Pr_Flag | Inf_R_Flag)? {1'b1,1'b0,32'b0}:
    //caso resta de 2 números iguales 
    (equals && ~operation_sign) ? {valid,mask,32'b0}:
    // Caso base
    {valid,mask,SA,Result};
endmodule

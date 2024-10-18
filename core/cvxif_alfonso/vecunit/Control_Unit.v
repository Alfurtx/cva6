`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.10.2023 14:55:05
// Design Name: 
// Module Name: Control_Unit
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
// Este módulo se encarga de gestionar los singos finales y las excepciones que entran directamente por el input principal

module Control_Unit(
input SA, //Signo del operando A ya swapeados
input SB, //Singo del operando B ya swapeados
input operation_code, //Entrada de la unidad de control principal. 0 para la suma 1 para la resta
input flag_1_a,  // a 1 si es infito o Nan
input flag_1_b,
input flag_0_a, // A 1 si es denormalized
input flag_0_b, 

output operation_sign,  //Control para la ALU,
output output_sign, // Signo de resultado final
output inf_nan_exception, // Si está a 1 hay o inifnity o Nan, por tanto pondremos la mascara a 0 al final de todo
output den_exception, // Si está a 1 hay o inifnity o Nan, por tanto pondremos la mascara a 0 al final de todo
output dend_flag
    );
    wire [1:0] inf_nan_flag;
    wire [1:0] den_flag;
    
assign output_sign = SA;
assign operation_sign = operation_code? SA ^ SB : ~(SA ^SB);
//  si alguno está a 1, hay exception
assign inf_nan_flag = {flag_1_a,flag_1_b};
assign den_flag = {flag_0_a,flag_0_b};

assign inf_nan_exception = |inf_nan_flag;
assign den_exception = |den_flag;
assign dend_flag = flag_0_a && flag_0_b;
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.10.2023 13:18:05
// Design Name: 
// Module Name: Adder_Substracter
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

//20/nov/23 = añadido el paso 4 de las diapos de pedro
module Adder_Substracter(
//En este modulo nos encargamos de sumar o restar las mantisas y de normalizar el primer resultado
// INPUTS //
input [23:0] significand_a,  //Mantissa más grande
input [23:0] significand_b, //Mantissa más pequeña
input operation_sign,            // Señal que recibimos para saber si sumamos o restamos.
// OUTPUTS //
output [24:0] result        //Resultado sin normalizar y sin redondear       
    );
wire [23:0]  ca2_significand_b;
wire GND = 0;
wire [23:0] b_in_CLA;
wire [23:0] inter_result;
wire cout;
 cla_noseg #(.BITS(24))
                           cla
                           (
                          // INPUTS //
                          ._a_in(significand_a),
                          ._b_in(b_in_CLA),
                          ._c_in(GND),
                          //OUTPUTS //
                          ._s_out(inter_result),
                          ._c_out(cout)                  
                          );
assign b_in_CLA = ~(operation_sign) ?  ca2_significand_b : significand_b;                        
assign ca2_significand_b = ~(significand_b) +1'b1;
assign result = {cout,inter_result}; 

//assign inter_result =operation ? significand_a + ca2_sigb : significand_a +significand_b ; 
 //significand_a + significand_b; //ESTE ES EL DEL ANTIGUO
//assign result = (equals && operation && inter_result[23] && (~inter_result[24])) ?   ~(inter_result) +1'b1 : inter_result; 
//assign result = operation? ((~inter_result) +1'b1) : inter_result;
//assign result = (equals && diff_sign && inter_result[23] && (~inter_result[24])) ? {inter_result[24],(~inter_result[23:0]) + 1'b1} : inter_result; 
endmodule

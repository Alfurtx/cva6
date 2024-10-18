`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.10.2023 10:53:41
// Design Name: 
// Module Name: Rounder
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


module Rounder(
//En este módulo vamos a redondear el resultado y a renormalizarlo si es necesario
input [1:0] guard,   //Los bits de guarda para redondear que me vienen desde el shifter
input [30:0] value,  //Valor normalizado a falta de rendondeo
input [1:0] rounding_code,
input sign,
output [31:0] result, //Valor redondeado y renormalizado //2 febrero añadimos 1 bit más para saber si hay overflow en el exponente. No tengo que tocar nada ya que Verilog trunca
output inf_r_flag // A 1 si hay excepción
    );
wire [23:0] round;
// Escogemos entre 4 tipos de redondeo: truncado, + o - infinito y nearest ties to even
assign round = 
rounding_code == 2'b00 ? // truncation
 value[22:0] :
rounding_code == 2'b01 ? // round to nearest ties to even
((guard[1] && value[0]) | (guard[1] && guard[0])) ? 1'b1 + value[22:0] : value[22:0] :
rounding_code == 2'b10 ? // towards + infinite
(value[0] | guard[1] | guard[0] ) ? 1'b1 + value[22:0] : value[22:0] :
rounding_code == 2'b11 ? // towards - infinite
(value[0] | guard[1] | guard[0] ) ?
value[22:0] - sign : // si el signo es 1 (negativo) se le restaría 1. SIno se deja como está
value[22:0] :
// default mode
value[22:0];

//Operador ternario, si no hacemos nada simplemente ponemos value, sino sumamos 1 a la mantissa
//assign round = guard[2] ?(guard[1] && guard[0]) ? 1'b1 + value[22:0] : value[0]? value[22:0] + 1'b1 : value[22:0] : value[22:0];
//último
//assign round = (guard[2] & guard[1] & guard[0] ) | (guard[2] & value[0] ) ? 1'b1 + value[22:0] : value[22:0];
//No pillo 1 bit de + como arriba, ya que al normalizar, se que si en el bit 24 hay un 1, habra" un
// desborde del estilo de "10,xxx" y habra que renormalizar 
//Si desborda, pillamos los 23 bits de mayor peso, sino los 23 bits de menor peso (normalizamos)
assign result[22:0] = round[23]  ? round[23:1]  :  round[22:0];
//sumamos 1 al exponente si hay carry, sino lo dejamos como esta
//Añadido el arreglo para el redondeo a - infinito
assign result[31:23] = round[23] ? 1'b1 + value[30:23] : (sign && ~(|value[22:0])) ? value[30:23] - 1'b1 : value[30:23];
assign inf_r_flag = result[31] ? 1'b1 : 1'b0;
    
endmodule

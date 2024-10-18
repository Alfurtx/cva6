`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.11.2023 09:15:17
// Design Name: 
// Module Name: pre_Rounder
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

//En este módulo agruparemos el exponente con la mantisa y realizaremos la lógica para elegir entre el resultado de la suma o de la resta
module pre_Rounder(
input [22:0] significand, //Mantisa normalizada que viene del barrel shifter
input [7:0] exponent, //Exponente normalizado que viene del priority encoder
input [7:0] raw_exponent, //Exponente sin normalizar por el priority encoder , 
input [24:0] raw_significand, //Mantissa sin normalizar por el barrel shifter
//input diff_sign,
input operation_sign,
input[4:0] shift,
input[2:0] guard,
input dend_flag,
//input swap,
output [31:0] result, //2 febrero añadimos 1 bit más para saber si hay overflow en el exponente. No tengo que tocar nada ya que Verilog trunca cuando pasa al rounder
output [1:0] guard_o,
output inf_pr_flag
    );
//wire[30:0] inter_result;

assign {result[31:23],result[22:0],guard_o[1],guard_o[0]} = !operation_sign ? 
//Resta
(~(|shift)) ? {exponent,significand,guard[2],(guard[1] | guard[0])} : (shift == 1) ? {exponent,significand,guard[1],guard[0]} : {exponent,significand,1'b0, 1'b0} :  
//Suma
raw_significand[24]  ? {(1'b1 + raw_exponent[7:0]),raw_significand[23:1],raw_significand[0],(guard[2] | guard[1] | guard[0])}  : (dend_flag && raw_significand[23]) ? {(1'b1 +  raw_exponent[7:0]),raw_significand[22:0],raw_significand[0],(guard[2] | guard[1] | guard[0])}  : {raw_exponent,raw_significand[22:0],guard[1],guard[0]};
assign inf_pr_flag = result[31] ? 1'b1 : 1'b0;
        
    // 22 nov 2023, actualizamos con caso 5 de la diapo
    //CASO 1
//assign {result[30:23],result[22:0],guard_o[1],guard_o[0]} =operation? {exponent,significand,guard[2],guard[1]|guard[0]} :
 //(~diff_sign && raw_significand[24]) ? {1'b1+raw_exponent,{raw_significand[23:1]},raw_significand[0],(|guard)} 
//CASO 2
// : (~(|shift)) ? {exponent,significand,guard[2],(guard[1] | guard[0])} : (shift == 1) ? {exponent,significand,guard[1],guard[0]} : {exponent,significand,1'b0, 1'b0} ;
//8 enero 2024, para la resta es necesario respetar el orden de operandos 
//assign result = (swap && operation) ? (~(inter_result + 1'b1)) : inter_result; 
 //antes de la prueba
// assign {result[30:23],result[22:0]} = operation ? {exponent[7:0],significand[22:0]}
//  : raw_significand[24]? {1'b1 + raw_exponent ,raw_significand[23:1]} : {raw_exponent,raw_significand[22:0]};

// assign {result[30:23],result[22:0]} = operation ? {exponent[7:0],significand[22:0]}
// : raw_significand[24]? {1'b1 + raw_exponent , (~(raw_significand[23:1] + 1))} : {raw_exponent, (~(raw_significand[22:0]))};
// LA 1A part va be, pero no entenc el perqué ja que me'n passe 2 del resultat bo. No se que passa si es al fer el ca2 que he de afegirli algo. Preguntar a pepe lo del pas 5 de la diapo
           
endmodule



`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.10.2023 15:44:54
// Design Name: 
// Module Name: Right_Shifter
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

//Este módulo se encarga de shitear a la derecha la mantisa B un número de veces "diff" y sacar los bits de guarda
// 4 dic 23 Ahora este módulo es el que se encarga de hacer el ca2 de la mantissa más pequeña y no el módulo de suma/resta
module Right_Shifter(
input [23:0] significand_i, // Mantisa más pequeña 
input [7:0] diff, // Diferencia de exponentes

output [2:0] guard, // Bits de guarda para redondeo
output [23:0] significand_o // Mantisa shifteada
    );
wire [32:0] round;

assign round = ({significand_i , 8'b0}>>diff);
assign significand_o = significand_i >> diff;
//Calculamos los 3 bits (guard,round y sticky) para luego aplicar el metodo de redondeo round to even
assign guard = {round[7],round[6],(|round[5:0])};
endmodule





//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VIEJA IMPLEMENTACIÓN //  CUANDO SE TENIA QUE AÑADIR 1 ENVEZ DE 0 POR EL SIGNO
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//assign ca2_sig = ~(significand_i) + 1'b1;
//assign ca2_inter =   diff_sign ? ca2_sig : significand_i;
//wire [32:0] round;
//wire [23:0] ca2_inter;
//wire [23:0] ca2_sig;
//wire signed [31:0] significand_comp;
//assign ca2_sig = ~(significand_i) + 1'b1;
//assign ca2_inter =   diff_sign ? ca2_sig : significand_i;
//// significand_i; // ESTÁ ASÍ EN EL ANTIGUO
//assign round = ({ca2_inter , 8'b0}>>diff);
//// 5 /12/23 Añadir 1's a la izquierda si se complementa a 2 la mantissa de B
//assign significand_comp = {8'hFF,ca2_inter};
//assign significand_o = equals? diff_sign?significand_comp[diff +23 -:24]:ca2_inter >> diff : ca2_inter >> diff; 
////Calculamos los 3 bits (guard,round y sticky) para luego aplicar el metodo de redondeo round to even
////Update 20/nov/23 : Ahora el bit de sticky se calcula haciendo la OR de los bits que sobran del shifteo
////30 Nov/23 asignaba mal los bits de guarda, ya que hacia 9,8 y 7:0 respectivamente
//assign guard = {round[7],round[6],(|round[5:0])};
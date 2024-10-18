`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.12.2023 15:52:53
// Design Name: 
// Module Name: CSA
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
module CSA #(
parameter BITS = 48
)
(
  input [BITS-1:0] a, b,c,
  output [BITS-1:0] sum,
  output [BITS-1:0] cout 
);
assign sum = a ^b ^ c;
assign cout [0] = 0;
assign cout[BITS-1 : 1] = (a&b) | (b&c) | (c&a);
endmodule




 // ANTIGUA IMPLEMENTACIÓN
//// Wire para desplazar el cout 1 bit
//wire [BITS - 1 : 0] w_cout;
//  // Generar instancias de FullAdder usando un bucle generate
//  genvar i;
//  generate
//    for (i = 0; i < BITS; i = i + 1) begin : gen_full_adders
//      fulladder FA (
//        .a(a[i]),
//        .b(b[i]),
//        .c(c[i]),
//        .sum(sum[i]),
//        .cout(w_cout[i])
//      );
//    end
//  endgenerate
//  
//  // Desplazamos cout 1 bit a la izquierda
//  assign cout = {w_cout[47:1],1'b0};




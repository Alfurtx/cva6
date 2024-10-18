`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.03.2024 11:27:38
// Design Name: 
// Module Name: bias_Substractor
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


module bias_Substractor (
    input [7:0] A,
    input [7:0] B,
    output [7:0] Difference,
    output Borrow_out,
    output overflow,
    output underflow
);

wire [7:0] B_inverted;
wire [8:0] Borrow_intermediate;
wire[7:0] inter_difference;

// Invertir los bits de B para obtener el complemento a 2
assign B_inverted = ((~B) + 1'b1);
assign Borrow_intermediate[0] = 0;

// Utilizar sumadores completos para realizar la resta
genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin : FA_loop
        fulladder FA (
            .a(A[i]),
            .b(B_inverted[i]),
            .c(Borrow_intermediate[i]),
            .sum(inter_difference[i]),
            .cout(Borrow_intermediate[i+1])
        );
    end
endgenerate

assign Borrow_out = Borrow_intermediate[8]; // Bit de acarreo de salida
assign overflow = 0;
assign Difference = |A ? inter_difference : 8'b0;

// -125 <= exp < 0
assign underflow = (~inter_difference[7] && ~(&inter_difference[6:0]) ) ? 1'b1 : 1'b0; 

endmodule


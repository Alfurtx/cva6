`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.01.2024 12:31:10
// Design Name: 
// Module Name: gen_prop
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

// Generar G' y P' también
//output G'    G'=G3 + G2P3 + G1P2P3 + G0P1P2P3
// output P'   P'= P0P1P2P3

module gen_prop_unit_2l#(
    parameter BITS = 4
)
(
input [BITS-1:0] G,P,
output  G_prime, P_prime
    );
    wire [BITS-1:0] G_star; // variable intermedia para G'

    
    assign G_star[0] = G[BITS - 1];
    
    generate
        
     genvar i;
               for (i = 1; i < BITS; i = i + 1)
                    begin: Gstar
                   assign G_star[i] = G[ BITS - i - 1 ] & (&P[ BITS -1 : BITS - i ]); 
               end
       endgenerate
       
     
     assign P_prime = &P;
     assign G_prime = |G_star;
     
endmodule
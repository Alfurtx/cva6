`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.02.2024 10:12:09
// Design Name: 
// Module Name: carry_unit
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

module carry_unit#(
	 parameter BITS = 4
  )
  (
  input wire [BITS -1 :0] G,P,
  input wire cin,
  output wire cout,
  output wire [BITS-1 : 0] carry
  );
  wire [BITS:0] C;
  assign C[0] = cin;
   genvar carryBitIndex;
     generate
         for (carryBitIndex = 1; carryBitIndex <= BITS; carryBitIndex = carryBitIndex + 1)
         begin:CBI
         
             wire [carryBitIndex:0] components;
             assign components[0] = G[carryBitIndex - 1];
 
             genvar i;
             for (i = 1; i < carryBitIndex; i = i + 1)
             begin:CBI
                 assign components[i] = G[carryBitIndex - i - 1] & &P[carryBitIndex - 1 : carryBitIndex - i];
             end
             assign components[carryBitIndex] = C[0] & &P[carryBitIndex - 1:0];
             assign C[carryBitIndex] = |components;
 
         end
     endgenerate
      assign cout = C[BITS];
      assign carry = C;
     
	   // ESTO NO HACE FALTA, YA QUE PARA EL GENERADOR DE CARRY DE 2N LEVEL LAS G' I P' LE ENTRAN COMO G Y P NORMALES
    // wire [BITS_PER_BLOCK  : 0] c_out; // 1 más ya que tenemos el del cin
    // 
    // assign c_out[0] = G_prime[BLOCK_NUM - 1];
    // 
    // assign c_out[BITS_PER_BLOCK] = (&P_prime & cin);    
    //     generate
    //         
    //      genvar i;
    //                for (i = 1; i < BITS_PER_BLOCK - 1; i = i + 1)
    //                begin: out
    //                    assign c_out[i] = G_prime[ BITS_PER_BLOCK - i - 1 ] && P_prime[ BITS_PER_BLOCK -1 : BITS_PER_BLOCK - i ]; 
    //                end
    //        endgenerate
    
    //assign cout = | c_out; ESTO VA A LA CLA UNIT 
endmodule

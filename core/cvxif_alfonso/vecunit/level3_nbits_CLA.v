`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.02.2024 11:37:29
// Design Name: 
// Module Name: level3_nbits_CLA
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


module level3_nbits_CLA#(
   parameter BITS =48,
   parameter BITS_PER_BLOCK =4 , // Bits por bloque CUIDADO CON LA DIVISIÓN PARA SACAR EL BLOCK_NUM
   parameter GROUP_NUM = 4, // Nº de grupos de bloques de 1er i 2do nivel
   parameter BLOCK_NUM =BITS / BITS_PER_BLOCK / GROUP_NUM // Nº de bloques dentro de gada grupo EN ESTE CASO DE ESTUDIO = 3
)
(
   input wire [BITS - 1 : 0] A_i,B_i,
   input wire cin,
   output wire [BITS - 1 : 0] S_o,
   output wire cout
);
// GND
wire [(BLOCK_NUM * GROUP_NUM) - 1 : 0] GND;
wire [GROUP_NUM - 1 : 0] GND2;

// Propagate / Generate
wire [BITS - 1:0] P;
wire [BITS - 1:0] G;
wire [BITS - 1 :0] A,B;
wire [(BLOCK_NUM * GROUP_NUM) -1 : 0] G_prime, P_prime;
wire [GROUP_NUM - 1 : 0] G_Pprime, P_Pprime; 

// carry gen 
wire [(GROUP_NUM * BLOCK_NUM) -1 : 0] carry_in1; // Contamos con el cin, pero no con el carry final de la suma
wire [GROUP_NUM -1 : 0] carry_in2;
wire [BITS -1 :0] carry_out;

assign A = A_i;
 assign B = B_i;
 
genvar i;
generate                                          
for (i = 0; i < (BLOCK_NUM * GROUP_NUM); i = i + 1) begin : CPA
    gen_prop_unit #(.BITS(BITS_PER_BLOCK)) GP (
        // INPUTS //
        .A(A[(i * BITS_PER_BLOCK) +: BITS_PER_BLOCK]),
        .B(B[(i * BITS_PER_BLOCK) +: BITS_PER_BLOCK]),
        // OUTPUTS //
        .P(P[(i * BITS_PER_BLOCK) +: BITS_PER_BLOCK]),
        .G(G[(i * BITS_PER_BLOCK) +: BITS_PER_BLOCK]),
        .G_prime(G_prime[i]),
        .P_prime(P_prime[i])
    );
    
    carry_unit #(.BITS(BITS_PER_BLOCK)) CU (
        // INPUTS //
        .G(G[(i * BITS_PER_BLOCK) +: BITS_PER_BLOCK]),
        .P(P[(i * BITS_PER_BLOCK) +: BITS_PER_BLOCK]),
        .cin(carry_in1[i]),
        // OUTPUTS //
        .cout(GND[i]),
        .carry(carry_out[(i * BITS_PER_BLOCK) +: BITS_PER_BLOCK])
    );
    
    sum_unit #(.BITS(BITS_PER_BLOCK)) SU (
        // INPUTS //
        .C(carry_out[(i * BITS_PER_BLOCK) +: BITS_PER_BLOCK]),
        .P(P[(i * BITS_PER_BLOCK) +: BITS_PER_BLOCK]),
        // OUTPUTS //
        .S_o(S_o[(i * BITS_PER_BLOCK) +: BITS_PER_BLOCK])
    );
end

for (i = 0; i < GROUP_NUM; i = i + 1) begin : CPA2
    gen_prop_unit_2l #(.BITS(BLOCK_NUM)) GP2 (
        // INPUTS //
        .P(P_prime[(i * BLOCK_NUM) +: BLOCK_NUM]),
        .G(G_prime[(i * BLOCK_NUM) +: BLOCK_NUM]),
        // OUTPUTS //
        .G_prime(G_Pprime[i]),
        .P_prime(P_Pprime[i])
    );

    carry_unit #(.BITS(BLOCK_NUM)) CU2 (
        // INPUTS //
        .G(G_prime[(i * BLOCK_NUM) +: BLOCK_NUM]),
        .P(P_prime[(i * BLOCK_NUM) +: BLOCK_NUM]),
        .cin(carry_in2[i]),
        // OUTPUTS //
        .cout(GND2[i]),
        .carry(carry_in1[(i * BLOCK_NUM) +: BLOCK_NUM])
    );
end
                       
endgenerate

// De este solo hace falta 1, que es el generador de  carrys de 3 nivel
 carry_unit#(.BITS(GROUP_NUM))
	                            CU3(
	                            // INPUTS //
	                            .G(G_Pprime),
	                            .P(P_Pprime),
	                            .cin(cin),
	                            // OUTPUTS //
	                            .cout(cout),
	                            .carry(carry_in2)
	                            );
  
endmodule

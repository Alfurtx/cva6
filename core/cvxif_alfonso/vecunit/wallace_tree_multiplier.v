`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.02.2024 14:11:16
// Design Name: 
// Module Name: wallace_tree_multiplier
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


module wallace_tree_multiplier#(
parameter BITS = 24, WIDTH = 2* BITS
)
(
input wire [(WIDTH * BITS) - 1 : 0] ppr,
output wire [WIDTH - 1:0] sum_o,cout
    );
    
    // NOMENCLATURA DE WIRES: el número a la derecha de "l" corresponde al nivel y el siguiente corresponde al indice del CSA dentro de el nivel
    // s y c corresponden a los outputs de suma y carry del CSA respectivamente
    
    // Nivel 1
    wire [(WIDTH * 8) - 1 :0] s_l1, c_l1;
    
    wire[WIDTH - 1 : 0]  s_l11, c_l11, s_l12, c_l12, s_l13, c_l13, s_l14, c_l14, s_l15, c_l15, s_l16, c_l16, s_l17, c_l17, s_l18, c_l18;
    
    // Nivel 2
    wire[WIDTH - 1 : 0]  s_l21, c_l21, s_l22, c_l22, s_l23, c_l23, s_l24, c_l24, s_l25, c_l25;
    
    // Nivel 3
    wire [WIDTH - 1 : 0] s_l31,c_l31,s_l32,c_l32,s_l33,c_l33;
    
    // Nivel 4
    wire [WIDTH - 1 : 0] s_l41,c_l41,s_l42,c_l42;
    
    // Nivel 5
    wire [WIDTH - 1 : 0] s_l51,c_l51,s_l52,c_l52;
    
    // Nivel 6
    wire [WIDTH - 1 : 0] s_l61,c_l61;

  // NIVEL 1
                       
genvar i;
                       generate
                           
                           for (i = 0; i < 8; i = i + 1) begin : level1
                               CSA l1_i(
                                   // INPUTS //
                                  .a(ppr[(i * 3 * WIDTH) +: WIDTH]),
                                  .b(ppr[((i * 3 + 1) * WIDTH) +: WIDTH]),
                                  .c(ppr[((i * 3 + 2) * WIDTH) +: WIDTH]),                      
                                   // OUTPUTS //
                                  .sum(s_l1[(i * (WIDTH)) +: WIDTH]),
                                  .cout(c_l1[(i * (WIDTH)) +: WIDTH])
                               );                      
                         end
                       endgenerate

 assign {s_l18, s_l17, s_l16,  s_l15, s_l14,  s_l13 , s_l12,  s_l11} = s_l1;
 assign {c_l18, c_l17, c_l16,  c_l15, c_l14,  c_l13 , c_l12,  c_l11} = c_l1;
 
// NIVEL 2
   
 //                     INPUTS           \\    OUTPUTS
 CSA l21 ( s_l11 , c_l11 , s_l12 , s_l21 , c_l21);
 CSA l22 ( c_l12 , s_l13 , c_l13 , s_l22 , c_l22);
 CSA l23 ( s_l14 , c_l14 , s_l15 , s_l23 , c_l23);
 CSA l24 ( c_l15 , s_l16 , c_l16 , s_l24 , c_l24);
 CSA l25 ( s_l17 , c_l17 , s_l18 , s_l25 , c_l25);
 
 // NIVEL 3
 
  //                     INPUTS           \\    OUTPUTS
 CSA l31 ( s_l21 , c_l21 , s_l22 , s_l31 , c_l31 );
 CSA l32 ( c_l22 , s_l23 , c_l23 , s_l32 , c_l32 );
 CSA l33 ( s_l24 , c_l24 , s_l25 , s_l33 , c_l33 );
 
 // NIVEL 4
 
   //                     INPUTS           \\    OUTPUTS
  CSA l41 ( s_l31 , c_l31 , s_l32 , s_l41 , c_l41 ); 
  CSA l42 ( c_l32 , s_l33 , c_l33 , s_l42 , c_l42 );
  
 // NIVEL 5 
 
  //                     INPUTS           \\    OUTPUTS
  CSA l51 ( s_l41 , c_l41 , s_l42 , s_l51 , c_l51 );
  CSA l52 ( c_l42 , c_l25 , c_l18 , s_l52 , c_l52 );
  
  // NIVEL 6
  
  //                     INPUTS           \\    OUTPUTS
  CSA l61 ( s_l51 , c_l51 , s_l52 , s_l61 , c_l61 ); 
  
  // NIVEL 7 
  //                     INPUTS           \\    OUTPUTS
  CSA l71 ( s_l61 , c_l61 , c_l52 , sum_o , cout );                 
                                             
endmodule

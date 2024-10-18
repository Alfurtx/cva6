`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.02.2024 16:44:33
// Design Name: 
// Module Name: result_Handler
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


module result_Handler(
input wire SA,SB,valid,mask,
input wire [47:0] mult_result,
input wire [7:0] exponent_sum,
input wire [1:0] round_code,
input wire overflow_2,
input wire underflow,
output wire exception,
output wire [33:0] final_result
    );
wire [8:0] normalized_Exponent; // Un bit más por si hace overflow al normalizar    
wire [22:0] adjusted_Significand;
wire guard,round,sticky;
wire [23:0] rounded_Significand; 
wire final_sign;

wire [8:0] final_Exponent; // Un bit más por el overflow   

assign final_sign = SA ^ SB;
assign {normalized_Exponent , adjusted_Significand} = mult_result[47] ? {(1'b1 + exponent_sum), mult_result [46 : 24]} : {exponent_sum , mult_result [45 : 23]} ;
  assign overflow_3 = normalized_Exponent[8] ? 1'b1 : 1'b0;
  // Los bits que nos sobran los guardamos para usarlos en el redondeo 
  assign {guard, round, sticky} = {mult_result[22],mult_result[21] , |mult_result[20:0]};
  
  assign rounded_Significand =
  round_code == 2'b00 ? // truncation
   adjusted_Significand :
  round_code == 2'b01 ? // round to nearest ties to even
  guard ? (adjusted_Significand[0] | round | sticky ) ? 1'b1 + adjusted_Significand : adjusted_Significand : adjusted_Significand :
  round_code == 2'b10 ? // towards + infinite
  (guard | sticky | round ) ? 1'b1 + adjusted_Significand : adjusted_Significand :
  round_code == 2'b11 ? // towards - infinite
  (guard | sticky | round ) ?
  adjusted_Significand - final_sign :
 adjusted_Significand:
  // default mode
  adjusted_Significand;
  
  assign final_Exponent = rounded_Significand[23] ? 1'b1 + normalized_Exponent : normalized_Exponent;
  // Volvemos a mirar el overflow
  assign overflow_4 = final_Exponent[8] ? 1'b1 : 1'b0;  
                                                                            

// RESULTADO FINAL , si hay overflow lo ponemos a 0 de momento. En un futuro pondremos la mascara a 0 para que no se opere con el valor
assign {exception,final_result} = (overflow_2 | overflow_3 | overflow_4) ? {1'b1,1'b0, 1'b0,32'd0} : {1'b0, valid, mask, final_sign , final_Exponent[7:0] , adjusted_Significand[22:0]};

endmodule

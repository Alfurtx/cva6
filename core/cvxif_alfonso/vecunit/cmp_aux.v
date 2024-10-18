`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.12.2023 16:13:17
// Design Name: 
// Module Name: logic_aux
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


module cmp_aux #(parameter DATA_WIDTH = 32, MVL = 16) (
    input clk_i,
    input rst,
    input start,
    input [1:0] cont_esc,
    input [DATA_WIDTH-1:0] op_esc,
//    input masked,
    input [MVL-1:0] mask,
    input [bitwidth(MVL)-1:0] VLR,
    input [32:0] arg1,
    input [32:0] arg2,
    output [33:0] out,
    output reg busy
    );
    wire [31:0] value1;
    wire [31:0] value2;
    wire [31:0] result;
    
    reg [bitwidth(MVL)-1:0] vlr_reg;
    reg [bitwidth(MVL)-1:0] counter;
    reg [1:0] cont_esc_reg;
    reg [DATA_WIDTH-1:0] op_esc_reg;
//    reg masked_op = 0;
    reg [MVL-1:0] mask_reg;
    
    assign value1 =     (~cont_esc_reg[1]) ? arg1[DATA_WIDTH-1:0] :
                                (cont_esc_reg[1] & cont_esc_reg[0]) ? arg1[DATA_WIDTH-1:0] : op_esc_reg;
    assign value2 =     (~cont_esc_reg[1]) ? arg2[DATA_WIDTH-1:0] :
                                (cont_esc_reg[1] & ~cont_esc_reg[0])    ? arg2[DATA_WIDTH-1:0] : op_esc_reg;
    assign result = value1 > value2;
    assign out = (arg1[32] & arg2[32]) ? {1'b1, mask_reg[counter], result} : {1'b0, 1'b0,result};
    always @(posedge clk_i) begin
        if (rst) begin
            vlr_reg <= 0;
            counter <= 0;
            cont_esc_reg <= 0;
            op_esc_reg <= 0;
            mask_reg <= 0;
            busy <= 0;
        end else if (start) begin
            vlr_reg <= VLR;
            counter <= 0;
            cont_esc_reg <= cont_esc;
            op_esc_reg <= op_esc;
            mask_reg <= mask;
            busy <= 1;
        end else if (busy) begin
            if (counter < vlr_reg) begin
                counter <= counter + 1;
            end else begin
                counter <= 0;
                busy <= 0;
            end
        end
    end
        
   //
   // Gets the log2 of a given number
   //
   // Params:
   // value, the value to obtain its log2
   //
   // Returns:
   // The log2 of the value
   //
   function integer log2(integer value);
   begin
   value = value-1;
   for (log2=0; value>0; log2=log2+1)
   value = value>>1;
   end
   endfunction
   
   //
   // Gets the number of bits required to encode a value
   //
   // Params:
   // value, the value to encode
   //
   // Returns:
   // The number of bits required to encode value input param
   //
   function integer bitwidth(integer value);
   begin                          
   if (value <= 1)
   bitwidth = 1;
   else
   bitwidth = log2(value);
   end
   endfunction
endmodule

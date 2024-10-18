`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.01.2024 12:22:13
// Design Name: 
// Module Name: Seg_Reg
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


module Seg_Reg #(parameter REG_SIZE = 0)(

    // INPUTS //
    input reset,
    input clk,
    
    input[REG_SIZE - 1 : 0] reg_in,
    
    // OUTPUTS //
    output reg [REG_SIZE - 1 : 0] reg_out_r
    );
    always @(posedge clk)
        begin
            if (reset)
            begin
            reg_out_r <= 0;
            end else
            begin
            reg_out_r <= reg_in;
            end
      end
endmodule

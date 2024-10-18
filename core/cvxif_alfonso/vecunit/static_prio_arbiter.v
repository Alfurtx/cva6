`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.11.2023 17:01:06
// Design Name: 
// Module Name: static_prio_arbiter
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


module static_prio_arbiter #(parameter WIDTH = 4) (
    input [WIDTH-1:0] vector_in,
    output [WIDTH-1:0] vector_out
    );
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i+1) begin: arbiter_gen
            assign vector_out[i] = (i==0) ? vector_in[0] : ((vector_in[i]) & (~|vector_in[(i-1) -: i]));
        end
    endgenerate
endmodule



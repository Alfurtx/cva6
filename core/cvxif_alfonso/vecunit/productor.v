`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.11.2023 15:49:03
// Design Name: 
// Module Name: productor
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


module productor(
        input clk_i,
        input [5:0] trabajo,
        input busy_consumer,
        output [5:0] select
    );
    
    assign select = (~busy_consumer) ? trabajo : 0;
    
//    assign s = (~busy_consumer) ? 3'b111 : 3'b000;
    
//    always @(posedge clk_i) begin
//        estado <= busy_consumer;
//    end
    
    
endmodule

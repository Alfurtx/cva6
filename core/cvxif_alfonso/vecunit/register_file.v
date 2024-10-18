`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.09.2023 15:45:22
// Design Name: 
// Module Name: register_file
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


module register_file #(parameter NUM_READ_PORTS=2, NUM_WRITE_PORTS=1,size_v=8,reg_num=5,DATA_LENGTH=8) (
    input [reg_num-1:0] rd1_i,
    input valid1,
    input [reg_num-1:0] rd2_i,
    input valid2,
    input [reg_num-1:0] wr_i,
    input [DATA_LENGTH-1:0] wr_d,
    input wr_valid,
    input clk_i,
    input en_i,
    output [DATA_LENGTH-1:0] s1_o,
    output [DATA_LENGTH-1:0] s2_o
    );
    reg[DATA_LENGTH-1:0] banco[0:(2**reg_num)-1][0:size_v-1];
    reg[DATA_LENGTH-1:0] leido1,leido2;
    
    integer index_r, index_w;
    initial
    begin
    index_r <= 0;
    index_w <= 0;
    end
    assign s1_o = leido1;
    assign s2_o = leido2;
    
    always @(rd1_i, rd2_i)
    index_r = 0;
    
    always @(posedge clk_i)
    begin
    if(wr_valid)
    begin
        banco[wr_i][index_w] <= wr_d;
        if(index_w==size_v-1)
            index_w=0;
            else
            index_w = index_w+1;
    end
    if(valid1 & valid2)
    begin
        leido1<=banco[rd1_i][index_r];
        leido2<=banco[rd2_i][index_r];
        if(index_r==size_v-1)
            index_r=0;
            else
            index_r = index_r+1;
    end 
    end
endmodule

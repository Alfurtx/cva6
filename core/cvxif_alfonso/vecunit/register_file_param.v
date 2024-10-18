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


module register_file_param #(parameter NUM_READ_PORTS=2, NUM_WRITE_PORTS=1,size_v=8,reg_num=5,DATA_LENGTH=8) (
    input [NUM_READ_PORTS*reg_num-1:0] rd1_i,
    input [NUM_READ_PORTS-1:0] valid,
    //input [reg_num-1:0] rd2_i,
    //input valid2,
    input [reg_num-1:0] wr_i,
    input [NUM_WRITE_PORTS*DATA_LENGTH-1:0] wr_d,
    input [NUM_WRITE_PORTS-1:0]wr_valid,
    input clk_i,
    input en_i,
    output [NUM_READ_PORTS*DATA_LENGTH-1:0] s1_o
    //output [DATA_LENGTH-1:0] s2_o
    );
    reg[DATA_LENGTH-1:0] banco[0:(2**reg_num)-1][0:size_v-1];
    reg[NUM_READ_PORTS*DATA_LENGTH-1:0] leido;
    
    integer index_r[0:NUM_READ_PORTS]; 
    integer index_w[0:NUM_WRITE_PORTS];
//    initial
//    begin
//    index_r[0:NUM_READ_PORTS] <= 0;
//    index_w <= 0;
//    end


//  Generate para generar todas las asignaciones a los fragmentos de "s1_o" correspondientes a cada puerto
    genvar s;
    generate
        for(s=0; s<NUM_READ_PORTS; s=s+1) begin: outputs
            assign s1_o[(s*DATA_LENGTH)+DATA_LENGTH-1:s*DATA_LENGTH] = leido[(s*DATA_LENGTH)+DATA_LENGTH-1:s*DATA_LENGTH];
        end
    endgenerate
    
//    always @(rd1_i, rd2_i)
//    index_r = 0;
    
//  Generate para generar las lecturas del banco de registro para cada puerto, y su asignación a su correspondiente slice de "leido"    
    genvar r;
    generate
        for(r = 0; r < NUM_READ_PORTS; r=r+1) begin: read_ports
            always @(posedge clk_i)
            begin
                if(valid[r])
                begin
                leido[(r*DATA_LENGTH)+DATA_LENGTH-1:r*DATA_LENGTH] <= banco[rd1_i[r*reg_num+reg_num-1:r*reg_num]][index_r[r]];
                if(index_r[r] == size_v-1)
                index_r[r] = 0;
                else
                index_r[r] = index_r[r]+1;
                end
            end
        end
    endgenerate
    
    genvar w;
    generate
        for(w = 0; w < NUM_READ_PORTS; w=w+1) begin: write_ports
            always @(posedge clk_i)
            begin
                if(wr_valid[w])
                begin
                banco[wr_i[w*reg_num+reg_num-1:w*reg_num]][index_w[w]] <= wr_d[w*DATA_LENGTH+DATA_LENGTH-1:w*DATA_LENGTH];
                if(index_w[w] == size_v-1)
                index_w[w] = 0;
                else
                index_w[w] = index_w[w]+1;
                end
            end
        end
    endgenerate
    
//    always @(posedge clk_i)
//    begin
//    if(wr_valid)
//    banco[wr_i][index_w] <= wr_d;
//    if(valid1)
//    leido1<=banco[rd1_i][index_r];
//    if(valid2)
//    leido2<=banco[rd2_i][index_r];
//    if(index_r==size_v-1)
//    index_r=0;
//    else
//    index_r = index_r+1;
//    if(index_w==size_v-1)
//    index_w=0;
//    else
//    index_w = index_w+1;
//    if(wr_en==1)
//    wr_i[wr_i] = 
//    end
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.02.2024 11:55:31
// Design Name: 
// Module Name: bram
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


module bram_dual_read   #(
	parameter WIDTH = 32,
	parameter DEPTH  = 10
	) (
		input clk,
		input rst,
		input [DEPTH-1:0] addr_A_read,
		input [DEPTH-1:0] addr_B_read,
		input [DEPTH-1:0] addr_write,
		input [WIDTH-1:0] data,
		input w_en,
		output [WIDTH-1:0] rd_A_o,
		output [WIDTH-1:0] rd_B_o
    );
    
    reg [WIDTH-1:0] mem [0:2**DEPTH-1];
    integer rst_mem;
    always @(posedge clk) begin
    	if (rst) begin
    		for(rst_mem = 0; rst_mem < 2**DEPTH; rst_mem = rst_mem + 1) begin
    			//mem[rst_mem] <= 0;
    		end
			mem[0] <= 1;
			mem[1] <= 4;
			mem[2] <= 9;
			mem[3] <= 16;
			mem[4] <= 25;
			mem[5] <= 36;
			mem[6] <= 49;
			mem[7] <= 64;
			mem[8] <= 81;
			mem[9] <= 100;
			mem[10] <= 121;
			mem[11] <= 144;
			mem[12] <= 169;
			mem[13] <= 196;
			mem[14] <= 225;
			mem[15] <= 256;
			
			
			//	5.0: 		32'b01000000101000000000000000000000
			//	10.0: 	32'b01000001001000000000000000000000
			mem[16] <= 2000;
			mem[17] <= 2500;
			mem[18] <= 3000;
			mem[19] <= 3500;
			mem[20] <= 4000;
			mem[21] <= 4500;
			mem[22] <= 5000;
			mem[23] <= 5500;
			mem[24] <= 6000;
			mem[25] <= 6500;
			mem[26] <= 7000;
			mem[27] <= 7500;
			mem[28] <= 8000;
			mem[29] <= 8500;
			mem[30] <= 9000;
			mem[31] <= 9500;
			mem[32] <= 10000;
			mem[33] <= 10500;
			mem[34] <= 11500;
			mem[35] <= 12000;
			mem[36] <= 12500;
			mem[37] <= 13000;
			mem[38] <= 13500;
			mem[39] <= 14000;
			mem[40] <= 14500;
			mem[41] <= 15000;
			mem[42] <= 15500;
			mem[43] <= 16000;
			mem[44] <= 16500;
			mem[45] <= 17000;
			mem[46] <= 17500;
			mem[47] <= 18000;
			
			mem[64] <= 2;
			mem[66] <= 4;
			mem[68] <= 6;
			mem[70] <= 8;
			mem[72] <= 10;
			mem[74] <= 12;
			mem[76] <= 14;
			mem[78] <= 16;
			mem[80] <= 18;
			mem[82] <= 20;
			mem[84] <= 22;
			mem[86] <= 24;
			mem[88] <= 26;
			mem[90] <= 28;
			mem[92] <= 30;
			mem[94] <= 32;
			mem[96] <= 34;
			mem[98] <= 36;
			mem[100] <= 38;
			mem[102] <= 40;
			mem[104] <= 42;
			mem[106] <= 44;
			mem[108] <= 46;
			mem[110] <= 48;
			mem[112] <= 50;
			mem[114] <= 52;
			mem[116] <= 54;
			mem[118] <= 56;
			mem[120] <= 58;
			mem[122] <= 60;
			mem[124] <= 62;
			mem[126] <= 64;
    	end else if (w_en) begin
    		mem[addr_write] <= data;
    	end
    end
    
    assign rd_A_o = mem[addr_A_read];
    assign rd_B_o = mem[addr_B_read];
    
    initial begin
    	for(rst_mem = 0; rst_mem < 2**DEPTH; rst_mem = rst_mem + 1) begin
			mem[rst_mem] <= 0;
		end
    end
    
    // synthesis translate_off
  	
    reg [15:0] tics;
    always @(posedge clk) begin
    	if (rst) begin
    		tics <= 0;
    	end else begin
    		tics <= tics + 1;
    	end
    end
    
    generate
        always @(posedge clk) begin
            if (w_en) begin
                $display ("Escritura memoria : posición %d : escrito = %d : tic %d", addr_write, data, tics+1'b1);
            end
        end
    endgenerate
    // synthesis translate_on
    
endmodule

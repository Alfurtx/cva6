`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.02.2024 10:18:29
// Design Name: 
// Module Name: prueba_instanciar_reg
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


module prueba_instanciar_reg #(parameter MVL = 32, NUM_REGS = 32, DATA_WIDTH = 32, MASK = 1, VALID = 1, NUM_WRITE_PORTS = 2, NUM_READ_PORTS = 4) (
		input clk,
		input rst,
		input [bitwidth(MVL)-1:0] vlr,
		input [(NUM_WRITE_PORTS*NUM_REGS)-1:0] w_signal,
		input [(NUM_READ_PORTS*NUM_REGS)-1:0] r_signal,
		input [(NUM_WRITE_PORTS*(DATA_WIDTH+VALID+MASK))-1:0] wd_i,
		output [NUM_REGS*(NUM_READ_PORTS*(DATA_WIDTH+VALID))-1:0] rd_o,
		output [NUM_REGS*NUM_WRITE_PORTS-1:0] busy_write,
		output [NUM_REGS*NUM_READ_PORTS-1:0] busy_read,
		output [NUM_REGS-1:0] first_elem
    );
    
    generate
    	genvar re;
    	for (re = 0; re < NUM_REGS; re = re + 1) begin: reginst
    		registro_dchinue #(
    			.NUM_WRITE_PORTS ( NUM_WRITE_PORTS ),
    			.NUM_READ_PORTS ( NUM_READ_PORTS ),
    			.DATA_WIDTH ( DATA_WIDTH ),
    			.VALID ( VALID ),
    			.MASK ( MASK ),
    			.MVL ( MVL )
			) reg_inst (
				.clk ( clk ),
				.rst ( rst ),
				.VLR ( vlr ),
				.w_signal ( w_signal[re * NUM_WRITE_PORTS +: NUM_WRITE_PORTS] ),
				.r_signal ( r_signal[re * NUM_READ_PORTS +: NUM_READ_PORTS] ),
				.wd_i ( wd_i ),
				.rd_o ( rd_o[re*(NUM_READ_PORTS*(DATA_WIDTH+VALID)) +: NUM_READ_PORTS*(DATA_WIDTH+VALID)] ),
				.busy_write ( busy_write[re * NUM_WRITE_PORTS +: NUM_WRITE_PORTS] ),
				.busy_read ( busy_read[re * NUM_READ_PORTS +: NUM_READ_PORTS] ),
				.first_elem ( first_elem[re] )
			);
    	end
    endgenerate
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
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

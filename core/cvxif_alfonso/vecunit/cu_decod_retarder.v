`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.11.2023 09:32:28
// Design Name: 
// Module Name: cu_segmented
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


module cu_decod_retarder #(
        parameter NUM_REGS = 4, 
                            NUM_WRITE_PORTS = 2, 
                            NUM_READ_PORTS = 2, 
                            DATA_WIDTH = 32,
                            VALID = 1,
                            WIDTH = DATA_WIDTH + VALID, 
                            MVL = 16, 
                            ADDRESS_WIDTH = 10, 
                            NUM_ALUS = 2
    ) (
        input clk_i,
        input add,
        input sub,
        input load,
        input store,
        input [bitwidth(NUM_REGS)-1:0] src1,
        input [bitwidth(NUM_REGS)-1:0] src2,
        input [bitwidth(NUM_REGS)-1:0] dst,
        input [ADDRESS_WIDTH-1:0] addr,
        input [bitwidth(MVL)-1:0] vector_length_reg,
        output reg add_o,
        output reg sub_o,
        output reg load_o,
        output reg store_o,
        output reg [bitwidth(NUM_REGS)-1:0] src1_o,
        output reg [bitwidth(NUM_REGS)-1:0] src2_o,
        output reg [bitwidth(NUM_REGS)-1:0] dst_o,
        output reg [ADDRESS_WIDTH-1:0] addr_o,
        output reg [bitwidth(MVL)-1:0] vector_length_reg_o
    );
    
    reg add_r;
    reg sub_r;
    reg load_r;
    reg store_r;
    reg [bitwidth(NUM_REGS)-1:0] src1_r;
    reg [bitwidth(NUM_REGS)-1:0] src2_r;
    reg [bitwidth(NUM_REGS)-1:0] dst_r;
    reg [ADDRESS_WIDTH-1:0] addr_r;
    reg [bitwidth(MVL)-1:0] vector_length_reg_r;
    
    always @(posedge clk_i) begin
        add_r <= add;
        sub_r <= sub;
        load_r <= load;
        store_r <= store;
        src1_r <= src1;
        src2_r <= src2;
        dst_r <= dst;
        addr_r <= addr;
        vector_length_reg_r <= vector_length_reg;
        
        add_o <= add_r;
        sub_o <= sub_r;
        load_o <= load_r;
        store_o <= store_r;
        src1_o <= src1_r;
        src2_o <= src2_r;
        dst_o <= dst_r;
        addr_o <= addr_r;
        vector_length_reg_o <= vector_length_reg_r;
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

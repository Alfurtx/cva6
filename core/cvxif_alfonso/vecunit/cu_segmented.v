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


module cu_segmented #(
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
        // Puertos Unidad Control
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
        // Puertos busys Unidad Vectorial ***FALTA AÑADIR LA ALU***
        input mem_w_busy,
        input mem_r_busy,
        input [NUM_WRITE_PORTS*NUM_REGS-1:0] bank_w_busy,
        input [NUM_READ_PORTS*NUM_REGS-1:0]  bank_r_busy,
        input [NUM_ALUS-1:0] alu_busy,
        input [NUM_REGS-1:0] first_elem,
        // Puertos señales hacia Unidad Vectorial
        output [bitwidth(MVL)-1:0] VLR,
        // Mem/reg Load/Store
        output mem_w_signal,
        output mem_r_signal,
        output [ADDRESS_WIDTH-1:0] addr_r,
        output [ADDRESS_WIDTH-1:0] addr_w,
        // Regireg stros vectoriales
        output [NUM_WRITE_PORTS*NUM_REGS-1:0] bank_w_signal,
        output [NUM_READ_PORTS*NUM_REGS-1:0]  bank_r_signal,
        // ALU  eg 
        output [1:0] op,
        output start_alu, ////////// IMPORTANTE ///////////
        // Muxereg s
        // Mux reg ALUs
        output [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0] alu_mux_sel_op1,
        output [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0] alu_mux_sel_op2,
        output [NUM_ALUS-1:0] start_mux_alu_op1,
        output [NUM_ALUS-1:0] start_mux_alu_op2,
        // Mux reg Mem/load/store
        output [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0] mem_mux_sel,
        output start_mux_mem,
        // Mux reg Write registers
        output [bitwidth(NUM_ALUS+1)-1:0] bank_write_sel,
        output [NUM_WRITE_PORTS*NUM_REGS-1:0] start_mux_bank_write,
        output stalling
    );
    
    wire add_dr_cu;
    wire sub_dr_cu;
    wire load_dr_cu;
    wire store_dr_cu;
    wire [bitwidth(NUM_REGS)-1:0] src1_dr_cu;
    wire [bitwidth(NUM_REGS)-1:0] src2_dr_cu;
    wire [bitwidth(NUM_REGS)-1:0] dst_dr_cu;
    wire [ADDRESS_WIDTH-1:0] addr_dr_cu;
    wire [bitwidth(MVL)-1:0] vector_length_reg_dr_cu;
    
    cu_decod_retarder #(
        .NUM_REGS ( NUM_REGS ),
        .NUM_WRITE_PORTS ( NUM_WRITE_PORTS ),
        .NUM_READ_PORTS ( NUM_READ_PORTS ),
        .DATA_WIDTH ( DATA_WIDTH ),
        .VALID ( VALID ),
        .WIDTH ( DATA_WIDTH + VALID),
        .MVL ( MVL ),
        .ADDRESS_WIDTH ( ADDRESS_WIDTH ),
        .NUM_ALUS ( NUM_ALUS )
    ) cd_dr1 (
        /////////////////
        // INPUTS //
        /////////////////
        .clk_i ( clk_i ),
        .add ( add ),
        .sub ( sub ),
        .load ( load ),
        .store ( store ),
        .src1 ( src1 ),
        .src2 ( src2 ),
        .dst ( dst ),
        .addr ( addr ),
        .vector_length_reg ( vector_length_reg ),
        //////////////////
        // Outputs //
        //////////////////
        .add_o ( add_dr_cu ),
        .sub_o ( sub_dr_cu ),
        .load_o ( load_dr_cu ),
        .store_o ( store_dr_cu),
        .src1_o ( src1_dr_cu ),
        .src2_o ( src2_dr_cu ),
        .dst_o ( dst_dr_cu ),
        .addr_o ( addr_dr_cu ),
        .vector_length_reg_o ( vector_length_reg_dr_cu )
    );
    
    control_unit #(
        .NUM_REGS ( NUM_REGS ),
        .NUM_WRITE_PORTS ( NUM_WRITE_PORTS ),
        .NUM_READ_PORTS ( NUM_READ_PORTS ),
        .DATA_WIDTH ( DATA_WIDTH ),
        .VALID ( VALID ),
        .WIDTH ( WIDTH ),
        .MVL ( MVL ),
        .ADDRESS_WIDTH ( ADDRESS_WIDTH),
        .NUM_ALUS ( NUM_ALUS )
    ) cu (
        ////////////////////
        //// Inputs ////
        ////////////////////
        .clk_i ( clk_i ),
        .add ( add_dr_cu ),
        .sub ( sub_dr_cu ),
        .load ( load_dr_cu ),
        .store ( store_dr_cu ),
        .src1 ( src1_dr_cu ),
        .src2 ( src2_dr_cu ),
        .dst ( dst_dr_cu ),
        .addr ( addr_dr_cu ),
        .vector_length_reg ( vector_length_reg_dr_cu ),
        .mem_w_busy ( mem_w_busy ),
        .mem_r_busy ( mem_r_busy ),
        .bank_w_busy ( bank_w_busy ),
        .bank_r_busy ( bank_r_busy ),
        .alu_busy ( alu_busy ),
        .first_elem ( first_elem ),
        //////////////////////
        //// Outputs ////
        //////////////////////
        .VLR ( VLR ),
        .mem_w_signal ( mem_w_signal ),
        .mem_r_signal ( mem_r_signal ),
        .addr_r ( addr_r ),
        .addr_w ( addr_w ),
        .bank_w_signal ( bank_w_signal ),
        .bank_r_signal ( bank_r_signal ),
        .op ( op ),
        .alu_mux_sel_op1 ( alu_mux_sel_op1),
        .alu_mux_sel_op2 ( alu_mux_sel_op2),
        .start_mux_alu_op1 ( start_mux_alu_op1 ),
        .start_mux_alu_op2 ( start_mux_alu_op2),
        .mem_mux_sel ( mem_mux_sel ),
        .start_mux_mem ( start_mux_mem ),
        .bank_write_sel ( bank_write_sel ),
        .start_mux_bank_write ( start_mux_bank_write ),
        .stalling ( stall )
    );
 
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

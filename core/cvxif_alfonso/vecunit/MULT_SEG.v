`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.03.2024 10:25:19
// Design Name: 
// Module Name: MULT_SEG
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


module MULT_SEG#(parameter NPP = 24, BITS = 24, WIDTH = 48, DATA_WIDTH = 32, MVL = 32, ID = 0)

(
// INPUTS //
input clk,
input reset,
input [32:0] operand_a,operand_b,  // Valid operand[31:0]
input [bitwidth(MVL):0] vlr_i,
input [MVL-1:0] mask_i,
input [1:0] cont_esc_i,
input [1+DATA_WIDTH-1:0] op_esc_i,
input start,
input [1:0] code_round, // 00 => Truncate
                                           // 01 => Round to nearest tie to event
                                           // 10 => Towards + infinite
                                           // 11 => Towards - infinite
// OUTPUTS //
output wire [33:0] final_result,  // Valid,result[31:0]
output reg busy
    );
    localparam valid_pos = DATA_WIDTH+1;
    wire SA;
    wire SB;
    wire [7:0] EA;
    wire [7:0] EB;
    wire [22:0] MA;
    wire [22:0] MB;
    wire valid_a;
    wire valid_b;
    wire mask;
    wire [1:0] round_code;
    
     
    // GENPP //
    
    wire [(NPP*WIDTH) -1 : 0 ] ppr_pp1;
    
    // EXP_ADD //
    
    wire GND = 0;
    wire [7:0] exp_sum_exp1;
    wire carry_out;
  //  wire overflow1_exp1;
    
    // SEG_REG_01 //
    wire valid_12; // de seg01 a seg02
    wire mask_12;
    wire [1:0] round_code_12;
    wire SA_12;
    wire SB_12;
    wire [7:0] exp_sum_1sub;
    wire [(NPP * WIDTH) - 1:0] ppr_gpwt;
    //wire overflow1_12;
    
    // WALLACE TREE //
    wire [WIDTH -1 : 0] wsum_wt2,wcout_wt2;
    
    //BIAS_SUBTRACTOR //
    wire [7:0] biased_exponent_sub2;
    wire cout_sub;
    wire underflow_sub2;
    wire overflow2_sub2;
    
    // SEG_REG_02 //
    wire valid_23;
    wire mask_23;
    wire [1:0] round_code_23;
    wire SA_23;
    wire SB_23;
    wire [7:0] biased_exponent_23;
    wire [WIDTH -1 : 0] wsum_2cla;
    wire [WIDTH -1 : 0] wcout_2cla;
    wire overflow1_23;
    wire overflow2_23;
    
    // CLA //
    wire GND2= 0;
    wire [WIDTH - 1 : 0] mult_result_cla3;
    wire cout_cla;
    
    // SEG_REG_03 //
    wire valid_3h;
    wire mask_3h;
    wire [1:0] round_code_3h;
    wire SA_3h;
    wire SB_3h;
    wire [7:0] biased_exponent_3h;
    wire [WIDTH - 1 : 0] mult_result_3h;
    wire overflow1_3h;
    wire overflow2_3h;
    
    // RESULT_HANDLER //
    wire exception_hout;
    wire [33:0] final_result_hout;
    
    // OPERATOR CONTROL //
    reg [bitwidth(MVL):0] vlr_reg;                             // Registro para almacenar el vlr                                                                 
    reg [bitwidth(MVL):0] count_mask;                          // Contador para indexar la máscara: se usa para elegir el bit de la máscara a enviar al operador 
    reg [bitwidth(9)-1:0] count_end;                           // Contador de elementos finalizados: cuenta los resultados que han atravesado ya todo el operador
                                                        
    reg [1:0] cont_esc_reg;                                    // Registro para almacenar el control escalar                                                    
    reg [1+DATA_WIDTH-1:0] op_esc_reg;                         // Registro para almacenar el operador escalar                                                             
    reg [MVL-1:0] mask_reg;                                    // Registro para almacenar la máscara
    
                                                                                                                     
    wire [DATA_WIDTH-1:0] value_a;                             // Wire que contiene el valor del operando 1       
    wire [DATA_WIDTH-1:0] value_b;                             // Wire que contiene el valor del operando 2       
    wire [DATA_WIDTH-1:0] value_result;                        // Wire que contiene el valor del resultado 
                                                               
                                                                       
    wire [32:0] true_operand_a;                                // Wire que contiene el operando 1 correcto (se elige entre operando 1 y operando escalar)        
    wire [32:0] true_operand_b;                                // Wire que contiene el operando 2 correcto (se elige entre operando 2 y operando escalar)        
                                                               // Este segundo caso no se da por lo que ya he comentado en otros lados                
                                                                  
    wire exception;                                                                             
                                                                                                
    assign value_a = true_operand_a[DATA_WIDTH-1:0];           // Value_a recibe el valor de true_operand_a (a es el operando 1)                      
    assign value_b = true_operand_b[DATA_WIDTH-1:0];           // Value_b recibe el valor de true_operand_b (b es el operando 2)                      
    assign value_result = final_result_hout[DATA_WIDTH-1:0];   // Value result recibe el valor del resultado final generado por el operador                      
    
    // Aquí se asignan los true_operands
    // En ambos casos se comprueba el control escalar para ver si hay operando escalar y cuál es: el fuente 1 o el fuente 2
    // De nuevo por el cambio en la decodificación, nunca se dará el caso de que el fuente 2 sea el escalar
    // De todas formas se explica: 
    // true_operand_a:
    //   si no hay operando escalar (o lo hay pero es el 2): true_operand_a = operand_a
    //   si hay operando escalar y es el 1: true_operand_a = {bit valid del operando escalar capturado, operador escalar capturado}
    // El caso para true_operand_b es igual pero opuesto
    assign true_operand_a = (~cont_esc_reg[1]) ? operand_a : {op_esc_reg[DATA_WIDTH],op_esc_reg[DATA_WIDTH-1:0]};
    assign true_operand_b = operand_b;
    
    // Operand_a assigns //
    assign valid_a = true_operand_a[32];
    assign SA = true_operand_a[31];
    assign EA =  true_operand_a[30:23];
    assign MA =  true_operand_a[22:0];
    
    // Operand_b assigns //
    assign valid_b = true_operand_b[32];
    assign SB = true_operand_b[31];
    assign EB = true_operand_b[30:23];
    assign MB = true_operand_b[22:0];
    
    assign valid = valid_a & valid_b;
    
    assign round_code = code_round;
    assign mask = mask_reg[(count_mask-1'b1)];  // Se envia al operador el bit de máscara indicado por el contador
 
 
      // Bloque always para controlar el las señales y registros, similar a otros vistos ya
      // Señal de reset -> se reincia todo
      // Señal de inicio -> se captura el vlr, se inician count_mask y count_end, se captura la máscara, 
      // se captura el control escalar, se captura el operando escalar y se pone busy activo
      // Mientras el operador esté busy:
      // Si el resultado que sale es válido y count_end < vlr, se incrementa count_end
      // Si el resultado que sale es válido y count_end == vlr, termina la operación -> busy = 0 y reiniciar contador
      // Si el dato entrante es valido y count_mask < vlr, se incrementa count_mask
 
    always@(posedge clk) begin
    if(reset) begin
        vlr_reg <= 0;
        count_mask <= 0;
        count_end <= 0;
        cont_esc_reg <= 0;
        op_esc_reg <= 0;
        mask_reg <= 0;
        busy <= 0;
    end if (start) begin
        vlr_reg <= vlr_i;
        count_mask <= 1;
        count_end <= 1;
        mask_reg <= mask_i;
        cont_esc_reg <= cont_esc_i;
        op_esc_reg <= op_esc_i;
        busy <= 1;
    end else if (busy) begin
        if(final_result_hout[valid_pos] & count_end < vlr_reg & (vlr_reg > 0)) begin
            count_end <= count_end + 1;
        end else if (final_result_hout[valid_pos] | (vlr_reg == 0)) begin
            count_end <= 0;
            busy <= 0;
        end
        if(valid & count_mask < vlr_reg) begin
            count_mask <= count_mask + 1;
        end else begin
            count_mask <= 0;
        end
    end
end
    
       // OUTPUT ASSIGNS //
       assign final_result = final_result_hout;
       assign exception = exception_hout;
       
        /////////////////////////////////
       // INSTANCIACIONES //
      ////////////////////////////////
      
      genpp#(.NPP(24), .WIDTH(48)) 
                       pp(
                       // INPUTS //
                       .MA(MA),
                       .MB(MB),
                       .EA(EA),
                       .EB(EB),
                       // OUTPUTS //
                       .pp(ppr_pp1)
                       );
        exponent_adder
                       expadd(
                       // INPUTS //
                       .EA(EA),
                       .EB(EB),
                       // OUTPUTS //
                       .exp_sum(exp_sum_exp1)
                       );
        Seg_Reg#(.REG_SIZE(1166))
                       seg_reg_01(
                       // INPUTS //
                       .reset(reset),
                       .clk(clk),
                       .reg_in({valid,
                       mask,
                       round_code,
                       SA,
                       SB,
                       exp_sum_exp1,
                       ppr_pp1}),
                       
                       // OUTPUTS //
                       .reg_out_r({valid_12,
                       mask_12,
                       round_code_12,
                       SA_12,
                       SB_12,
                       exp_sum_1sub,
                       ppr_gpwt})                      
                       );
          wallace_tree_multiplier#(.BITS(BITS),.WIDTH(WIDTH))
                       wt(
                       // INPUTS //
                       .ppr(ppr_gpwt),
                       // OUTPUTS //
                       .sum_o(wsum_wt2),
                       .cout(wcout_wt2)
                        );
            bias_Substractor
                       sub(
                       // INPUTS //
                       .A(exp_sum_1sub),
                       .B(8'd127),
                       // OUTPUTS //
                       .Difference(biased_exponent_sub2),
                       .Borrow_out(cout_sub),
                       .overflow(overflow2_sub2),
                       .underflow(underflow_sub2)
                       );
               Seg_Reg#(.REG_SIZE(112))
                       seg_reg_02(
                       // INPUTS //
                        .reset(reset),
                        .clk(clk),
                        .reg_in({valid_12,
                        mask_12,
                        round_code_12,
                        SA_12,
                        SB_12,
                        biased_exponent_sub2,
                        overflow2_sub2,
                        underflow_sub2,
                        wsum_wt2,
                        wcout_wt2
                        }),
                       // OUTPUTS //
                       .reg_out_r({valid_23,
                       mask_23,
                       round_code_23,
                       SA_23,
                       SB_23,
                       biased_exponent_23,
                       overflow2_23,
                       underflow_23,
                       wsum_2cla,
                       wcout_2cla
                       })
                       );                               
             level3_nbits_CLA#(.BITS(WIDTH),.BITS_PER_BLOCK(4),.GROUP_NUM(4))
                        cla(
                        // INPUTS //
                        .A_i(wsum_2cla),
                        .B_i(wcout_2cla),
                        .cin(GND2),
                        // OUTPUTS //
                        .S_o(mult_result_cla3),
                        .cout(cout_cla) // no nos hace falta
                        );
               Seg_Reg#(.REG_SIZE(64))
                       seg_reg_03(
                       // INPUTS //
                       .reset(reset),
                       .clk(clk),
                       .reg_in({valid_23,
                       mask_23,
                       round_code_23,
                       SA_23,
                       SB_23,
                       biased_exponent_23,
                       mult_result_cla3,
                       overflow2_23,
                       underflow_23}),
                       // OUTPUTS //         
                       .reg_out_r({valid_3h,
                       mask_3h,
                       round_code_3h,
                       SA_3h,
                       SB_3h,
                       biased_exponent_3h,
                       mult_result_3h,
                       overflow2_3h,
                       underflow_3h})
                       );
                 result_Handler
                       rh(
                       // INPUTS //
                       .valid(valid_3h),
                       .mask(mask_3h),
                       .SA(SA_3h),
                       .SB(SB_3h),
                       .mult_result(mult_result_3h),
                       .exponent_sum(biased_exponent_3h),
                       .round_code(round_code_3h),
                       .overflow_2(overflow2_3h),
                       .underflow(underflow_3h),
                       // OUTPUTS //
                       .exception(exception_hout),
                       .final_result(final_result_hout)
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

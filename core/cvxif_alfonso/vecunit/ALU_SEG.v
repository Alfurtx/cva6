/////////////////////////////////////////////////
// FERRAN MAS FAUS -- GAP UPV //
///////////////////////////////////////////////

`timescale 1ns / 1ps

module ADD_SUB_SEG #(
    parameter DATA_WIDTH = 32,
    parameter MVL = 32,
    parameter ID = 0
) (
// INPUTS //
input clk,
input reset,
input [32:0] operand_a,             // Valid,operand_a[31:0]
input [32:0] operand_b,             // Valid,operand_b[31:0]
input [bitwidth(MVL):0] vlr_i,
input [MVL-1:0] mask_i,
input operation_code_i,             // 0 => Addition
                                    // 1 => Substraction
input [1:0] cont_esc_i,
input [1+DATA_WIDTH-1:0] op_esc_i,
input start,
input[1:0] code_round,              // 00 => Truncate
                                    // 01 => Round to nearest tie to event
                                    // 10 => Towards + infinite
                                    // 11 => Towards - infinite

// OUTPUTS //
output [33:0] final_result, // Valid,Mask,result[31:0]
output reg busy  
);

localparam valid_pos = DATA_WIDTH+1;
///////////////////////
// TOP INPUTS //
/////////////////////

reg operation_code;
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
wire [30:0] a_operand;
wire [30:0] b_operand;
//wire switch_length; // 1 para 32 bits y 0 para 64 bits

//////////////////////////////////
// EXPONENT_CHECK //
////////////////////////////////

wire flag_1_a_s1;
wire flag_1_b_s1;
wire flag_0_a_s1;
wire flag_0_b_s1;


///////////////////////////////////////
// SUBSTRACTOR_8_BITS //
/////////////////////////////////////

wire [7:0] exponent_diff_s1; // de 8 bit sub a seg01
wire swap_s1; // de 8 bit sub a seg1 
wire [1:0] hidden_s1; // de 8 bit sub a seg 1
wire equals_s1;


/////////////////////////
// REG_SEG_01 //
///////////////////////

wire SA_1sw; // de seg01 a sign swap
wire SB_1sw; // de seg01 a sign swap
wire [7:0] EA_1sw; // de seg01 a exponent_swap
wire [7:0] EB_1sw; // de seg01 a exponent_swap
wire [22:0] MA_1sw; // de seg01 a significand swap
wire [22:0] MB_1sw; // de seg01 a significand swap
wire swap_1sw; // de seg01 a significand y exponent swap
wire [1:0] hidden_1sw; // de seg01 a significand swap
wire [7:0] exponent_diff_12; // de seg01 a seg02
wire valid_12; // de seg01 a seg02
wire operation_12; // de seg01 a seg02
wire mask_12;
wire flag_1_a_12;
wire flag_1_b_12;
wire flag_0_a_12;
wire flag_0_b_12;
wire [1:0] round_code_12;
wire equals_12;

////////////////////////////////
// EXPONENT_SWAP //
//////////////////////////////

wire [7:0] EA_sw2; // de exponent swap a seg02
wire equals_sw2; // de exponent swap a seg2

//////////////////////////////////
// SIGNIFICAND SWAP //
/////////////////////////////////

wire [23:0] MA_sw2; // de significand swap a seg02
wire [23:0] MB_sw2; // de significand swap a seg02

///////////////////////
// SIGN SWAP //
//////////////////////

wire SA_sw2; // de sign swap a seg02
wire SB_sw2; // de sign swap a seg02

/////////////////////////
// REG_SEG_02 //
///////////////////////

wire SA_2c; // de seg02 a control
wire SB_2c; // de seg02 a control
wire [7:0] exponent_diff_2sh; // de seg02 a shifter
wire [7:0] EA_23; // de seg02 a seg03
wire [23:0] MA_23; // de seg02 a seg03
wire [23:0] MB_2sh; // de seg02 a shifter
wire valid_23; // de seg02 a seg03
wire operation_2c; // de seg02 a control
wire mask_23; // de seg02 a seg03
wire [1:0] round_code_23; // de seg02 a seg03
wire flag_1_a_2c;
wire flag_1_b_2c;
wire flag_0_a_2c;
wire flag_0_b_2c;
wire equals_23;


////////////////////
// CONTROL //
///////////////////

wire operation_sign_c3; // de control a seg03
wire final_sign_c3; // de control a seg03
wire inf_nan_flag_c3; // flag de inifnity o nan
wire den_flag_c3; // flag de denormalized
wire dend_flag_c3; // flag para saber si los 2 operadores son denormalizados


///////////////////
// SHIFTER //
/////////////////

wire [2:0] guard_sh3; // de shifter a seg03
wire [23:0] MB_sh3; // de shifter a seg03

/////////////////////////
// REG_SEG_03 //
///////////////////////

wire final_sign_34; // de seg03 a seg04
wire operation_sign_3as; // de seg03 a add/sub
wire [7:0] EA_34; // de seg03 a seg04
wire [22:0] MA_34; // de seg03 a seg04
wire [23:0] MA_3as; // de seg03 a add/sub
wire [23:0] MB_3as; // de seg03 a add/sub
wire [2:0] guard_34; // de seg03 a seg04
wire valid_34; // de seg03 a seg04
wire mask_34; // de seg03 a seg04
wire [1:0] round_code_34; // de seg03 a seg04
wire den_flag_34; // de seg03 a seg04
wire inf_nan_flag_34; // de seg03 a seg04
wire dend_flag_34;
wire equals_34;

///////////////////////////////////////
// ADDER_SUBSTRACTER //
/////////////////////////////////////

wire [24:0] result_as4; // de add/sub a seg04

/////////////////////////
// REG_SEG_04 //
///////////////////////

wire final_sign_45; // de seg04 a seg05
wire [7:0] EA_45; // de seg04 a seg05
wire [23:0] MA_45;
wire [24:0] result_45; // de seg04 a seg05
wire [2:0] guard_45; // de seg04 a seg05
wire valid_45; // de seg04 a seg05
wire operation_sign_45;
wire [1:0] round_code_45;
wire mask_45;
wire den_flag_45;
wire inf_nan_flag_45;
wire dend_flag_45;
wire equals_45;

//////////////////////////////////
// PRIORITY ENCODER //
/////////////////////////////////

wire [7:0] normalized_Exponent_pe5; // de priority encoder a seg05
wire [4:0] shift_pe5; // de priority encoder a seg05

/////////////////////////
// REG_SEG_05 //
///////////////////////

wire final_sign_56; // de seg05 a seg06
wire [7:0] EA_56; // de seg05 a seg06
wire [23:0] MA_56;
wire [7:0] normalized_Exponent_56; // de seg05 a seg06
wire [4:0] shift_5bs; // de seg05 a barrell shifter
wire [24:0] result_56; // de seg05 a seg06
wire [2:0] guard_56; // de seg05 a seg06
wire valid_56; // de seg05 a seg06
wire operation_sign_56;
wire [1:0] round_code_56;
wire mask_56;
wire den_flag_56;
wire inf_nan_flag_56;
wire dend_flag_56;
wire equals_56;

////////////////////////////////
// BARRELL SHIFTER //
///////////////////////////////

wire [22:0] normalized_Significand_bs6; // de barrell shifter a reg06
wire [4:0] shift_bs6;

/////////////////////////
// REG_SEG_06 //
///////////////////////

wire final_sign_67; // de seg06 a seg07
wire [7:0] EA_6pr; // de seg06 a pre rounder
wire [23:0] MA_67;
wire [7:0] normalized_Exponent_6pr; // de seg06  a pre rounder
wire [22:0] normalized_Significand_6pr; // de seg06 a pre rounder
wire [24:0] result_6pr; // de seg06 a pre rounder
wire [2:0] guard_6pr; // de seg06 a pre rounder 
wire valid_67; // de seg06 a seg07
wire [4:0] shift_6pr;
wire operation_sign_6pr;
wire [1:0] round_code_67;
wire mask_67;
wire den_flag_67;
wire inf_nan_flag_67;
wire dend_flag_6pr;
wire equals_67;

////////////////////////////
//  PRE ROUNDER //
//////////////////////////

wire [30:0] result_pr7; // de pre rounder a seg07
wire [1:0] guard_pr7 ; // de pre rouder a seg07
wire inf_pr_flag_pr7;

/////////////////////////
// REG_SEG_07 //
///////////////////////

wire final_sign_78; // de seg07 a seg08
wire [7:0] EA_78;
wire [23:0] MA_78;
wire [30:0] result_7r; // de seg07 a rounder
wire [1:0] guard_7r; // de seg07 a rounder
wire valid_78; // de seg07 a final
wire [1:0] round_code_7r;
wire mask_78;
wire inf_pr_flag_78;
wire den_flag_78;
wire inf_nan_flag_78;
wire dend_flag_78;
wire operation_sign_78;
wire equals_78;

/////////////////////
// ROUNDER //
///////////////////

wire [30:0] result_r8; // de rounder a final
wire inf_r_flag_r8;

/////////////////////////
// SEG_REG_08 //
///////////////////////

wire valid_8h;
wire mask_8h;
wire final_sign_8h;
wire [7:0] EA_8h;
wire [30:0] result_8h;
wire [23:0] MA_8h;
wire den_flag_8h;
wire inf_nan_flag_8h;
wire inf_pr_flag_8h;
wire inf_r_flag_8h;
wire dend_flag_8h;
wire operation_sign_8h;
wire equals_8h;

///////////////////////////////////////
// EXCEPTION_HANDLER //
////////////////////////////////////

wire [33:0] final_result_hout;

//////////////////////
// OPERATOR CONTROL //
//////////////////////
reg [bitwidth(MVL):0] vlr_reg;                            // Registro para almacenar el vlr
reg [bitwidth(MVL):0] count_mask;                         // Contador para indexar la máscara: se usa para elegir el bit de la máscara a enviar al operador
reg [bitwidth(MVL):0] count_end;                          // Contador de elementos finalizados: cuenta los resultados que han atravesado ya todo el operador
reg [1:0] cont_esc_reg;                                   // Registro para almacenar el control escalar
reg [1+DATA_WIDTH-1:0] op_esc_reg;                        // Registro para almacenar el operando escalar
reg [MVL-1:0] mask_reg;                                   // Registro para almacenar la máscara

wire [DATA_WIDTH-1:0] value_a;                            // Wire que contiene el valor del operando 1
wire [DATA_WIDTH-1:0] value_b;                            // Wire que contiene el valor del operando 2
wire [DATA_WIDTH-1:0] value_result;                       // Wire que contiene el valor del resultado

wire [32:0] true_operand_a;                               // Wire que contiene el operando 1 correcto (se elige entre operando 1 y operando escalar)
wire [32:0] true_operand_b;                               // Wire que contiene el operando 2 correcto (se elige entre operando 2 y operando escalar)
                                                          // Este segundo caso no se da por lo que ya he comentado en otros lados

assign value_a = true_operand_a[DATA_WIDTH-1:0];          // Value_a recibe el valor de true_operand_a (a es el operando 1)
assign value_b = true_operand_b[DATA_WIDTH-1:0];          // Value_b recibe el valor de true_operand_b (b es el operando 2)
assign value_result = final_result_hout[DATA_WIDTH-1:0];  // Value result recibe el valor del resultado final generado por el operador

// Aquí se asignan los true_operands
// En ambos casos se comprueba el control escalar para ver si hay operando escalar y cuál es: el fuente 1 o el fuente 2
// De nuevo por el cambio en la decodificación, nunca se dará el caso de que el fuente 2 sea el escalar
// De todas formas se explica: 
// true_operand_a:
//   si no hay operando escalar (o lo hay pero es el 2): true_operand_a = operand_a
//   si hay operando escalar y es el 1: true_operand_a = {bit valid del operando escalar capturado, operador escalar capturado}
// El caso para true_operand_b es igual pero opuesto
assign true_operand_a = (~cont_esc_reg[1] | (cont_esc_reg[1] &  cont_esc_reg[0]))  ? operand_a : {op_esc_reg[DATA_WIDTH],op_esc_reg[DATA_WIDTH-1:0]};
assign true_operand_b = (~cont_esc_reg[1] | (cont_esc_reg[1] & ~cont_esc_reg[0]))  ? operand_b : {op_esc_reg[DATA_WIDTH],op_esc_reg[DATA_WIDTH-1:0]};


// En esta secuencia de assigns, se les dan valores a los wires que utiliza Ferran en su operador
// (eso ya no controlo como funciona, solo le paso los cmapos que necesita)
assign valid_a = true_operand_a[32];
assign a_operand = true_operand_a[30:0];
assign b_operand = true_operand_b[30:0];
assign SA = true_operand_a[31];
//assign EA = switch_length ?  BUS [BUS_WIDTH - 3 : BUS_WIDTH - 10] : BUS [BUS_WIDTH - 3 : BUS_WIDTH - 13];
assign EA =  true_operand_a[30:23];
//assign MA = switch_length ?  BUS [BUS_WIDTH - 11 : BUS_WIDTH - 33] : BUS [BUS_WIDTH - 14 : BUS_WIDTH - 65];
assign MA =  true_operand_a[22:0];
assign valid_b = true_operand_b[32];
assign SB = true_operand_b[31];
//assign EB = switch_length ? BUS [OPERATOR_LENGTH - 2 : OPERATOR_LENGTH - 9] : BUS[OPERATOR_LENGTH - 2 :OPERATOR_LENGTH - 12];
assign EB = true_operand_b[30:23];
//assign MB = switch_length ?  BUS [OPERATOR_LENGTH - 10 : 0] : BUS[OPERATOR_LENGTH - 13 : 0] ;
assign MB = true_operand_b[22:0];


assign valid = valid_a & valid_b;             // El valid es el resultado de la and entre los valids de los operandos
assign mask = mask_reg[(count_mask-1'b1)];    // Se envia al operador el bit de máscara indicado por el contador
assign round_code = code_round;



  // Bloque always para controlar el las señales y registros, similar a otros vistos ya
  // Señal de reset -> se reincia todo
  // Señal de inicio -> se captura el vlr, se inician count_mask y count_end, se captura el código de operación
  // (ya que estamos en una suma y hay que indicar si se suma o se resta), se captura la máscara, se captura el control escalar,
  // se captura el operando escalar y se pone busy activo
  // Mientras el operador esté busy:
  // Si el resultado que sale es válido y count_end < vlr, se incrementa count_end
  // Si el resultado que sale es válido y count_end == vlr, termina la operación -> busy = 0 y reiniciar contador
  // Si el dato entrante es valido y count_mask < vlr, se incrementa count_mask

always@(posedge clk)
begin
    if(reset) begin
        vlr_reg <= 0;
        count_mask <= 1;
        count_end <= 1;
        operation_code <= 0;
        cont_esc_reg <= 0;
        op_esc_reg <= 0;
        mask_reg <= 0;
        busy <= 0;
    end if (start) begin
        vlr_reg <= vlr_i;
        count_mask <= 1;
        count_end <= 1;
        operation_code <= operation_code_i;
        mask_reg <= mask_i;
        cont_esc_reg <= cont_esc_i;
        op_esc_reg <= op_esc_i;
        busy <= 1;
    end else if (busy) begin
        if((final_result_hout[valid_pos] & count_end < vlr_reg) & (vlr_reg > 0)) begin
            count_end <= count_end + 1;
        end else if (final_result_hout[valid_pos] | (vlr_reg == 0)) begin
            count_end <= 1;
            busy <= 0;
        end
        if(valid & count_mask < vlr_reg) begin
            count_mask <= count_mask + 1;
        end else begin
            count_mask <= 1;
        end
    end
end

//////////////////
// OUTPUT //
////////////////

assign final_result = final_result_hout;    

/////////////////////////////////
// INSTANCIACIONES //
///////////////////////////////

Exponent_Check Exp_Check(
                                             // INPUTS //
                                             .EA(EA),
                                             .EB(EB),
                                             // OUTPUTS //
                                             .flag_1_a(flag_1_a_s1),
                                             .flag_1_b(flag_1_b_s1),
                                             .flag_0_a(flag_0_a_s1),
                                             .flag_0_b(flag_0_b_s1)
                                             ); 

Substractor_8_Bits Sub8(
                                          // INPUTS //
                                         .operand_a(a_operand),
                                         .operand_b(b_operand),
                                         // OUPUTS //
                                         .exponent_diff(exponent_diff_s1),
                                         .swap(swap_s1),
                                         .hidden(hidden_s1),
                                         .equals(equals_s1)
                                         );
//Significand_Check Man_Check(
//                                                     // INPUTS //
//                                                     .MA(MA),
//                                                     .MB(MB),
//                                                     // OUTPUTS //
//                                                     .flag_a(man_flag_a_s1),
//                                                     .flag_b(man_flag_b_s1)
//                                                     );                                        
Seg_Reg #(.REG_SIZE (85) ) 
                                         Seg_Reg_01(
                                                                        
                                          // INPUTS //                                         
                                         .reset(reset),
                                         .clk(clk),
                                         
                                         .reg_in({valid,
                                         mask,
                                         SA,
                                         EA,
                                         MA,
                                         SB,
                                         EB,
                                         MB,
                                         swap_s1,
                                         hidden_s1,
                                         operation_code,
                                         exponent_diff_s1,
                                         round_code,
                                         flag_1_a_s1,
                                         flag_1_b_s1,
                                         flag_0_a_s1,
                                         flag_0_b_s1,
                                         equals_s1
                                         }),
                                                                              
                                         // OUTPUTS //
                                         .reg_out_r({valid_12,
                                         mask_12,
                                         SA_1sw,
                                         EA_1sw,
                                         MA_1sw,
                                         SB_1sw,
                                         EB_1sw,
                                         MB_1sw,
                                         swap_1sw,
                                         hidden_1sw,
                                         operation_12,
                                         exponent_diff_12,
                                         round_code_12,
                                         flag_1_a_12,
                                         flag_1_b_12,
                                         flag_0_a_12,
                                         flag_0_b_12,
                                         equals_12
                                         })
                                         );
                                                             
Exponent_Swap ExSwp(
                                          // INPUTS //
                                          .exponent_a(EA_1sw),
                                          .exponent_b(EB_1sw),
                                          .swap(swap_1sw),
                                          // OUPUTS //
                                          .exponent_A(EA_sw2)
                                          );  
                                                                                                                                                            
Significand_Swap SgSwp(
                                          // INPUTS //
                                          .significand_a(MA_1sw),
                                          .significand_b(MB_1sw),
                                          .swap(swap_1sw),
                                          .hidden(hidden_1sw),
                                          // OUTPUTS //
                                          .significand_A(MA_sw2),
                                          .significand_B(MB_sw2)
                                          );
                                          
Sign_Swap SignSwp        (
                                          // INPUTS //
                                          .SA(SA_1sw),
                                          .SB(SB_1sw),
                                          .swap(swap_1sw),
                                          // OUTPUTS //
                                          .SA_o(SA_sw2),
                                          .SB_o(SB_sw2)
                                          );
                                          
Seg_Reg #(.REG_SIZE (76) ) 
                                          Seg_Reg_02(
                                           // INPUTS //
                                          .clk(clk),
                                          .reset(reset),
                                          
                                           .reg_in({valid_12,
                                           mask_12,
                                           operation_12,
                                           SA_sw2,
                                           EA_sw2,
                                           MA_sw2,
                                           SB_sw2,
                                           MB_sw2,
                                           exponent_diff_12,
                                           round_code_12,
                                           flag_1_a_12,
                                           flag_1_b_12,
                                           flag_0_a_12,
                                           flag_0_b_12,
                                           equals_12
                                           }),                                           
                                          // OUTPUTS //
                                          .reg_out_r({valid_23,
                                          mask_23,
                                          operation_2c,
                                          SA_2c,
                                          EA_23,
                                          MA_23,
                                          SB_2c,
                                          MB_2sh,
                                          exponent_diff_2sh,
                                          round_code_23,
                                          flag_1_a_2c,
                                          flag_1_b_2c,
                                          flag_0_a_2c,
                                          flag_0_b_2c,
                                          equals_23
                                          })                                                                      
                                          );
Control_Unit Control       (
                                          // INPUTS //
                                          .SA(SA_2c),
                                          .SB(SB_2c),
                                          .operation_code(operation_2c),
                                          .flag_1_a(flag_1_a_2c),
                                          .flag_1_b(flag_1_b_2c),
                                          .flag_0_a(flag_0_a_2c),
                                          .flag_0_b(flag_0_b_2c),                                  
                                          // OUTPUTS //
                                          .operation_sign(operation_sign_c3),
                                          .output_sign(final_sign_c3),
                                          .inf_nan_exception(inf_nan_flag_c3),
                                          .den_exception(den_flag_c3),
                                          .dend_flag(dend_flag_c3)
                                          );
Right_Shifter Rsh            (
                                          // INPUTS //
                                          .significand_i(MB_2sh),
                                          .diff(exponent_diff_2sh),
                                          // OUTPUTS //
                                          .guard(guard_sh3),
                                          .significand_o(MB_sh3)
                                          );
Seg_Reg #(.REG_SIZE (69) ) 
                                          Seg_Reg_03(
                                          // INPUTS //
                                          .clk(clk),
                                          .reset(reset),
                                          
                                          .reg_in({valid_23,
                                          mask_23,
                                          EA_23,
                                          MA_23,
                                          MB_sh3,
                                          final_sign_c3,
                                          operation_sign_c3,
                                          guard_sh3,
                                          round_code_23,
                                          den_flag_c3,
                                          dend_flag_c3,
                                          inf_nan_flag_c3,
                                          equals_23
                                          }),
                                          // OUTPUTS //
                                          .reg_out_r({valid_34,
                                          mask_34,
                                          EA_34,
                                          MA_3as,
                                          MB_3as,
                                          final_sign_34,
                                          operation_sign_3as,
                                          guard_34,
                                          round_code_34,
                                          den_flag_34,
                                          dend_flag_34,
                                          inf_nan_flag_34,
                                          equals_34
                                          })                                        
                                          );
Adder_Substracter AS    (
                                          // INPUTS //
                                          .significand_a(MA_3as),
                                          .significand_b(MB_3as),
                                          .operation_sign(operation_sign_3as),
                                          // OUTPUTS //
                                          .result(result_as4)
                                          );
Seg_Reg #(.REG_SIZE (70) )                                                              
                                          Seg_Reg_04(
                                          // INPUTS //
                                          .clk(clk),
                                          .reset(reset),
                                          
                                          .reg_in({valid_34,
                                          mask_34,
                                          operation_sign_3as,
                                          final_sign_34,
                                          EA_34,
                                          MA_3as,
                                          result_as4,
                                          guard_34,
                                          round_code_34,
                                          den_flag_34,
                                          dend_flag_34,
                                          inf_nan_flag_34,
                                          equals_34
                                          }),                                      
                                          // OUTPUTS //                                          
                                          .reg_out_r({valid_45,
                                          mask_45,
                                          operation_sign_45,
                                          final_sign_45,
                                          EA_45,
                                          MA_45,
                                          result_45,
                                          guard_45,
                                          round_code_45,
                                          den_flag_45,
                                          dend_flag_45,
                                          inf_nan_flag_45,
                                          equals_45
                                          })
                                          );
Priority_Encoder PE        (
                                          // INPUTS //
                                          .exponent(EA_45),
                                          .significand(result_45),
                                          // OUTPUTS //
                                          .shift(shift_pe5),
                                          .normalized_Exponent(normalized_Exponent_pe5)
                                          );
Seg_Reg #(.REG_SIZE (83) ) 
                                          Seg_Reg_05(
                                          // INPUTS //
                                          .clk(clk),
                                          .reset(reset),
                                          
                                          .reg_in({valid_45,
                                          mask_45,
                                          operation_sign_45,
                                          final_sign_45,
                                          EA_45,
                                          MA_45,
                                          normalized_Exponent_pe5,
                                          shift_pe5,
                                          result_45,
                                          guard_45,
                                          round_code_45,
                                          den_flag_45,
                                          dend_flag_45,
                                          inf_nan_flag_45,
                                          equals_45
                                          }),
                                          // OUTPUTS //
                                          .reg_out_r({valid_56,
                                          mask_56,
                                          operation_sign_56,
                                          final_sign_56,
                                          EA_56,
                                          MA_56,
                                          normalized_Exponent_56,
                                          shift_5bs,
                                          result_56,
                                          guard_56,
                                          round_code_56,
                                          den_flag_56,
                                          dend_flag_56,
                                          inf_nan_flag_56,
                                          equals_56
                                          })
                                          );
                                          
barrel_Shifter BS              (
                                          // INPUTS //
                                          .significand(result_56[22:0]),
                                          .shift(shift_5bs),
                                          .g(guard_56[2]),
                                          // OUTPUTS //
                                          .normalized_Significand(normalized_Significand_bs6),
                                          .shift_o(shift_bs6)
                                          );
Seg_Reg #(.REG_SIZE (106) ) 
                                          Seg_Reg_06(
                                          // INPUTS //
                                          .clk(clk),
                                          .reset(reset),
                                          
                                          .reg_in({valid_56,
                                          mask_56,
                                          operation_sign_56,
                                          final_sign_56,
                                          EA_56,
                                          MA_56,
                                          normalized_Exponent_56,
                                          normalized_Significand_bs6,
                                          result_56,
                                          guard_56,
                                          shift_bs6,
                                          round_code_56,
                                          den_flag_56,
                                          dend_flag_56,
                                          inf_nan_flag_56,
                                          equals_56
                                          }),                                         
                                          // OUPUTS //
                                          .reg_out_r({valid_67,
                                          mask_67,
                                          operation_sign_6pr,
                                          final_sign_67,
                                          EA_6pr,
                                          MA_67,
                                          normalized_Exponent_6pr,
                                          normalized_Significand_6pr,
                                          result_6pr,
                                          guard_6pr,
                                          shift_6pr,
                                          round_code_67,
                                          den_flag_67,
                                          dend_flag_6pr,
                                          inf_nan_flag_67,
                                          equals_67
                                          })
                                          );
 pre_Rounder  PR            (
                                          // INPUTS //
                                          .significand(normalized_Significand_6pr),
                                          .exponent(normalized_Exponent_6pr),
                                          .raw_exponent(EA_6pr),
                                          .raw_significand(result_6pr),
                                          .shift(shift_6pr),
                                          .guard(guard_6pr),
                                          .operation_sign(operation_sign_6pr),
                                          .dend_flag(dend_flag_6pr),
                                          // OUTPUTS //
                                          .result(result_pr7),
                                          .guard_o(guard_pr7),
                                          .inf_pr_flag(inf_pr_flag_pr7)
                                          );
Seg_Reg #(.REG_SIZE (76) ) 
                                          Seg_Reg_07(
                                          // INPUTS //
                                          .clk(clk),
                                          .reset(reset),
                                          
                                          .reg_in({valid_67,
                                          mask_67,
                                          final_sign_67,
                                          result_pr7,
                                          guard_pr7,
                                          round_code_67,
                                          EA_6pr,
                                          MA_67,
                                          den_flag_67,
                                          inf_nan_flag_67,
                                          dend_flag_6pr,
                                          inf_pr_flag_pr7,
                                          equals_67,
                                          operation_sign_6pr
                                          }),
                                          // OUTPUTS //
                                          .reg_out_r({valid_78,
                                          mask_78,
                                          final_sign_78,
                                          result_7r,
                                          guard_7r,
                                          round_code_7r,
                                          EA_78,
                                          MA_78,
                                          den_flag_78,
                                          inf_nan_flag_78,
                                          dend_flag_78,
                                          inf_pr_flag_78,
                                          equals_78,
                                          operation_sign_78                                         
                                          })
                                          );                       
Rounder Rnd                   (
                                          // INPUTS //
                                          .guard(guard_7r),
                                          .value(result_7r),
                                          .rounding_code(round_code_7r),
                                          .sign(final_sign_78),
                                          // OUTPUTS //
                                          .result(result_r8),
                                          .inf_r_flag(inf_r_flag_r8)                                        
                                          );
Seg_Reg#(.REG_SIZE (73))
                                          Seg_Reg_08(
                                          // INPUTS //
                                          .clk(clk),
                                          .reset(reset),
                                          
                                          .reg_in({valid_78,
                                          mask_78,
                                          final_sign_78,
                                          result_r8,
                                          EA_78,
                                          MA_78,
                                          den_flag_78,
                                          inf_nan_flag_78,
                                          inf_pr_flag_78,
                                          dend_flag_78,
                                          inf_r_flag_r8,
                                          equals_78,
                                          operation_sign_78
                                          }),
                                          // OUTPUTS //
                                          .reg_out_r({valid_8h,
                                          mask_8h,
                                          final_sign_8h,
                                          result_8h,
                                          EA_8h,
                                          MA_8h,
                                          den_flag_8h,
                                          inf_nan_flag_8h,
                                          inf_pr_flag_8h,
                                          dend_flag_8h,
                                          inf_r_flag_8h,
                                          equals_8h,
                                          operation_sign_8h
                                          }) 
                                          );
                                          
Exception_Handler Han (
                                         // INPUTS //
                                         .valid(valid_8h),
                                         .mask(mask_8h),
                                         .SA(final_sign_8h),
                                         .EA(EA_8h),
                                         .MA(MA_8h),
                                         .Result(result_8h),
                                         .Den_Flag(den_flag_8h),
                                         .dend_flag(dend_flag_8h),
                                         .Inf_Control_Flag(inf_nan_flag_8h),
                                         .Inf_Pr_Flag(inf_pr_flag_8h),
                                         .Inf_R_Flag(inf_r_flag_8h),
                                         .equals(equals_8h),
                                         .operation_sign(operation_sign_8h),
                                         // OUTPUTS //
                                         .Final_Result(final_result_hout)	
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
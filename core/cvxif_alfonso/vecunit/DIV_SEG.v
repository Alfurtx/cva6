/////////////////////////////////////////////////
// FERRAN MAS FAUS -- GAP UPV //
///////////////////////////////////////////////

`timescale 1ns / 1ps
module DIV_SEG #(
    parameter DATA_WIDTH = 32,
    parameter MVL = 32,
    parameter ID = 0
)   (
// INPUTS //
    input clk,
    input reset,
    input start,
    input [32:0] operand_a,operand_b,  // Valid operand[31:0]
    input [bitwidth(MVL):0] vlr_i,
    input [MVL-1:0] mask_i,
    input [1:0] cont_esc_i,
    input [1+DATA_WIDTH-1:0] op_esc_i,
    
    output wire [33:0] final_result,  // Valid,Mask,result[31:0]
    output reg busy
);
    
    localparam valid_pos = DATA_WIDTH+1;
    
    wire SA;
    wire SB;
    wire [7:0] EA;
    wire [7:0] EB;
    wire [22:0] MA;
    wire [22:0] MB;
    wire [47:0] ma; // La parte alta todo a 0
    wire [23:0] mb;
    wire valid_a;
    wire valid_b;
    wire mask;
    wire valid;
    wire zero;
    
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
    assign value_result = final_result[DATA_WIDTH-1:0];       // Value result recibe el valor del resultado final generado por el operador
    
    // Aquí se asignan los true_operands
    // En ambos casos se comprueba el control escalar para ver si hay operando escalar y cuál es: el fuente 1 o el fuente 2
    // De nuevo por el cambio en la decodificación, nunca se dará el caso de que el fuente 2 sea el escalar
    // De todas formas se explica: 
    // true_operand_a:
    //   si no hay operando escalar (o lo hay pero es el 2): true_operand_a = operand_a
    //   si hay operando escalar y es el 1: true_operand_a = {bit valid del operando escalar capturado, operador escalar capturado}
    // El caso para true_operand_b es igual pero opuesto
    assign true_operand_a = (~cont_esc_reg[1] | (cont_esc_reg[1] &  cont_esc_reg[0]))  ? operand_a : op_esc_reg;
    assign true_operand_b = (~cont_esc_reg[1] | (cont_esc_reg[1] & ~cont_esc_reg[0]))  ? operand_b : op_esc_reg;
    
    assign {valid_a,SA,EA,MA} = true_operand_a;
    assign {valid_b,SB,EB,MB} = true_operand_b;
    assign mask = mask_reg[(count_mask-1'b1)];  // Se envia al operador el bit de máscara indicado por el contador
    assign valid = valid_a & valid_b;
     
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
            if((final_result[valid_pos] & count_end < vlr_reg) & (vlr_reg > 0)) begin
                count_end <= count_end + 1;
            end else if (final_result[valid_pos] | (vlr_reg == 0)) begin
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
    
    //Hidden bit y señal de división entre 0
    assign ma = |EA? {1'b1,MA,23'b0} : {1'b0,MA,23'b0};
    assign {mb} = |EB? {1'b1,MB} : {1'b0,MB};
    assign zero = (~|EB & ~|MB);
    
   
    

    //Restador de Exponentes//
    wire [7:0] exponent_sub;
    //Sumador de Bias//
    wire[7:0] biased_exponent;
    wire overflow1;
    //Unidad de Control//
    wire output_sign, inf_nan_excepion ,op_exception;
    wire [1:0] den_exception;
    //Divisor de Mantisas//
    wire[23:0] rp_1l,rp_2l,rp_3l,rp_4l,rp_5l,rp_6l,rp_7l,rp_8l,rp_9l,rp_10l,rp_11l,rp_12l,rp_13l,rp_14l,rp_15l,rp_16l,rp_17l,rp_18l,rp_19l,rp_20l,rp_21l,rp_22l,rp_23l;
    wire[24:0] rp_24l,rp_25l,rp_26l,rp_27l,rp_28l,rp_29l,rp_30l,rp_31l,rp_32l,rp_33l,rp_34l,rp_35l,rp_36l,rp_37l,rp_38l,rp_39l,rp_40l,rp_41l,rp_42l,rp_43l,rp_44l,rp_45l,rp_46l,rp_47l,rp_48l;
    wire[23:0] cout_1l,cout_2l,cout_3l,cout_4l,cout_5l,cout_6l,cout_7l,cout_8l,cout_9l,cout_10l,cout_11l,cout_12l,cout_13l,cout_14l,cout_15l,cout_16l,cout_17l,cout_18l,cout_19l,cout_20l,cout_21l,cout_22l,cout_23l;
    wire[24:0] cout_24l,cout_25l,cout_26l,cout_27l,cout_28l,cout_29l,cout_30l,cout_31l,cout_32l,cout_33l,cout_34l,cout_35l,cout_36l,cout_37l,cout_38l,cout_39l,cout_40l,cout_41l,cout_42l,cout_43l,cout_44l,cout_45l,cout_46l,cout_47l,cout_48l;
    wire res_1l,res_2l,res_3l,res_4l,res_5l,res_6l,res_7l,res_8l,res_9l,res_10l,res_11l,res_12l,res_13l,res_14l,res_15l,res_16l,res_17l,res_18l,res_19l,res_20l,res_21l,res_22l,res_23l,res_24l,res_25l,res_26l,res_27l,res_28l,res_29l,res_30l,res_31l,res_32l,res_33l,res_34l,res_35l,res_36l,res_37l,res_38l,res_39l,res_40l,res_41l,res_42l,res_43l,res_44l,res_45l,res_46l,res_47l,res_48l;
    //Manejador de Resultado//
    // Seg_Reg_01//
	wire									   valid_12;
	wire									   mask_12;
	wire									   SA_12;
	wire									   SB_12;
	wire[7:0]							   exponent_sub_12;
	wire									   flag_1_a_12;
	wire									   flag_1_b_12;
	wire									   flag_0_a_12;
	wire									   flag_0_b_12;
	wire[47:0]							   ma_12;
	wire[23:0]							   mb_12;
	wire									   res_1l_12;
	wire									   res_2l_12;
	wire[23:0]							   rp_2l_12;
	wire									   zero_12;     
    // Seg_Reg_02//
wire                                       valid_23;
wire									   mask_23;
wire									   SA_23;
wire									   SB_23;
wire[7:0	]					     	   biased_exponent_23;
wire									   flag_1_a_23;
wire									   flag_1_b_23;
wire									   flag_0_a_23;
wire									   flag_0_b_23;
wire									  overflow1_23;
wire[47:0]							   ma_23;
wire[23:0]							   mb_23;
wire									   res_1l_23;
wire									   res_2l_23;
wire									   res_3l_23;
wire									   res_4l_23;
wire[23:0]							   rp_4l_23;
wire									   zero_23;
    // Seg_Reg_03//
wire                                          valid_34;
wire										   mask_34;
wire										   output_sign_34;
wire[7:0]								   biased_exponent_34;
wire										   op_exception_34;
wire										   inf_nan_exception_34;
wire[1:0]                                  den_exception_34;
wire[47:0]								   ma_34;
wire[23:0]								   mb_34;
wire										   res_1l_34;
wire										   res_2l_34;
wire										   res_3l_34;
wire										   res_4l_34;
wire										   res_5l_34;
wire										   res_6l_34;
wire[23:0]								   rp_6l_34;
wire										   zero_34; 
    // Seg_Reg_04//
wire                                          valid_45;
wire										   mask_45;
wire										   output_sign_45;
wire[7:0]								   biased_exponent_45;
wire										   op_exception_45;
wire										   inf_nan_exception_45;
wire[1:0]								   den_exception_45;
wire[47:0]								   ma_45;
wire[23:0]								   mb_45;
wire										   res_1l_45;
wire										   res_2l_45;
wire										   res_3l_45;
wire										   res_4l_45;
wire										   res_5l_45;
wire										   res_6l_45;
wire										   res_7l_45;
wire										   res_8l_45;
wire[23:0]								   rp_8l_45;
wire										   zero_45;
    // Seg_Reg_05//
wire                                           valid_56;
wire										   mask_56;
wire										   output_sign_56;
wire[7:0]								   biased_exponent_56;
wire										   op_exception_56;
wire										   inf_nan_exception_56;
wire[1:0]								   den_exception_56;
wire[47:0]								   ma_56;
wire[23:0]								   mb_56;
wire										   res_1l_56;
wire										   res_2l_56;
wire										   res_3l_56;
wire										   res_4l_56;
wire										   res_5l_56;
wire										   res_6l_56;
wire										   res_7l_56;
wire										   res_8l_56;
wire										   res_9l_56;
wire										   res_10l_56;
wire[23:0]								   rp_10l_56;
wire										   zero_56; 
    // Seg_Reg_06//
wire                                           valid_67;
wire										   mask_67;
wire										   output_sign_67;
wire[7:0]								   biased_exponent_67;
wire										   op_exception_67;
wire										   inf_nan_exception_67;
wire[1:0]								   den_exception_67;
wire[47:0]								   ma_67;
wire[23:0]								   mb_67;
wire										   res_1l_67;
wire										   res_2l_67;
wire										   res_3l_67;
wire										   res_4l_67;
wire										   res_5l_67;
wire										   res_6l_67;
wire										   res_7l_67;
wire										   res_8l_67;
wire										   res_9l_67;
wire										   res_10l_67;
wire										   res_11l_67;
wire										   res_12l_67;
wire[23:0]								   rp_12l_67;
wire										   zero_67;  
    // Seg_Reg_07//
wire                                          valid_78;
wire										   mask_78;
wire										   output_sign_78;
wire[7:0]								   biased_exponent_78;
wire										   op_exception_78;
wire										   inf_nan_exception_78;
wire[1:0]								   den_exception_78;
wire[47:0]								   ma_78;
wire[23:0]								   mb_78;
wire										   res_1l_78;
wire										   res_2l_78;
wire										   res_3l_78;
wire										   res_4l_78;
wire										   res_5l_78;
wire										   res_6l_78;
wire										   res_7l_78;
wire										   res_8l_78;
wire										   res_9l_78;
wire										   res_10l_78;
wire										   res_11l_78;
wire										   res_12l_78;
wire										   res_13l_78;
wire										   res_14l_78;
wire[23:0]								   rp_14l_78;
wire										   zero_78; 
    // Seg_Reg_08//
wire                                          valid_89;
wire										   mask_89;
wire										   output_sign_89;
wire[7:0]								   biased_exponent_89;
wire										   op_exception_89;
wire										   inf_nan_exception_89;
wire[1:0]								   den_exception_89;
wire[47:0] 							   ma_89;
wire[23:0]								   mb_89;
wire										   res_1l_89;
wire										   res_2l_89;
wire										   res_3l_89;
wire										   res_4l_89;
wire										   res_5l_89;
wire										   res_6l_89;
wire										   res_7l_89;
wire										   res_8l_89;
wire										   res_9l_89;
wire										   res_10l_89;
wire										   res_11l_89;
wire										   res_12l_89;
wire										   res_13l_89;
wire										   res_14l_89;
wire										   res_15l_89;
wire										   res_16l_89;
wire[23:0]								   rp_16l_89;
wire										   zero_89;  
    // Seg_Reg_09//
wire                                           valid_910;
wire										   mask_910;
wire										   output_sign_910;
wire[7:0]								   biased_exponent_910;
wire										   op_exception_910;
wire										   inf_nan_exception_910;
wire[1:0]								   den_exception_910;
wire[47:0]								   ma_910;
wire[23:0]								   mb_910;
wire										   res_1l_910;
wire										   res_2l_910;
wire										   res_3l_910;
wire										   res_4l_910;
wire										   res_5l_910;
wire										   res_6l_910;
wire										   res_7l_910;
wire										   res_8l_910;
wire										   res_9l_910;
wire										   res_10l_910;
wire										   res_11l_910;
wire										   res_12l_910;
wire										   res_13l_910;
wire										   res_14l_910;
wire										   res_15l_910;
wire										   res_16l_910;
wire										   res_17l_910;
wire										   res_18l_910;
wire[23:0]								   rp_18l_910;
wire										   zero_910;  
    // Seg_Reg_10//
wire                                          valid_1011;
wire										   mask_1011;
wire										   output_sign_1011;
wire[7:0]								   biased_exponent_1011;
wire										   op_exception_1011;
wire										   inf_nan_exception_1011;
wire[1:0]								   den_exception_1011;
wire[47:0]								   ma_1011;
wire[23:0]								   mb_1011;
wire										   res_1l_1011;
wire										   res_2l_1011;
wire										   res_3l_1011;
wire										   res_4l_1011;
wire										   res_5l_1011;
wire										   res_6l_1011;
wire										   res_7l_1011;
wire										   res_8l_1011;
wire										   res_9l_1011;
wire										   res_10l_1011;
wire										   res_11l_1011;
wire										   res_12l_1011;
wire										   res_13l_1011;
wire										   res_14l_1011;
wire										   res_15l_1011;
wire										   res_16l_1011;
wire										   res_17l_1011;
wire										   res_18l_1011;
wire										   res_19l_1011;
wire										   res_20l_1011;
wire[23:0]								   rp_20l_1011;
wire										   zero_1011; 
    // Seg_Reg_11//
wire                                           valid_1112;
wire										   mask_1112;
wire										   output_sign_1112;
wire[7:0]								   biased_exponent_1112;
wire										   op_exception_1112;
wire										   inf_nan_exception_1112;
wire[1:0]								   den_exception_1112;
wire[47:0] 							   ma_1112;
wire[23:0]								   mb_1112;
wire										   res_1l_1112;
wire										   res_2l_1112;
wire										   res_3l_1112;
wire										   res_4l_1112;
wire										   res_5l_1112;
wire										   res_6l_1112;
wire										   res_7l_1112;
wire										   res_8l_1112;
wire										   res_9l_1112;
wire										   res_10l_1112;
wire										   res_11l_1112;
wire										   res_12l_1112;
wire										   res_13l_1112;
wire										   res_14l_1112;
wire										   res_15l_1112;
wire										   res_16l_1112;
wire										   res_17l_1112;
wire										   res_18l_1112;
wire										   res_19l_1112;
wire										   res_20l_1112;
wire										   res_21l_1112;
wire										   res_22l_1112;
wire[23:0]								   rp_22l_1112;
wire										   zero_1112;  
    // Seg_Reg_12//
wire                                       valid_1213;
wire									   mask_1213;
wire									   output_sign_1213;
wire[7:0]							   biased_exponent_1213;
wire									   op_exception_1213;
wire						               inf_nan_exception_1213;
wire[1:0]		    				   den_exception_1213;
wire[47:0]							   ma_1213;
wire[23:0]							   mb_1213;
wire									   res_1l_1213;
wire									   res_2l_1213;
wire									   res_3l_1213;
wire									   res_4l_1213;
wire									   res_5l_1213;
wire									   res_6l_1213;
wire									   res_7l_1213;
wire									   res_8l_1213;
wire									   res_9l_1213;
wire									   res_10l_1213;
wire									   res_11l_1213;
wire									   res_12l_1213;
wire									   res_13l_1213;
wire									   res_14l_1213;
wire									   res_15l_1213;
wire									   res_16l_1213;
wire									   res_17l_1213;
wire									   res_18l_1213;
wire									   res_19l_1213;
wire									   res_20l_1213;
wire									   res_21l_1213;
wire									   res_22l_1213;
wire									   res_23l_1213;
wire									   res_24l_1213;
wire[24:0]							   rp_24l_1213;
wire									   zero_1213;  
    // Seg_Reg_13//
wire                                           valid_1314;
wire										   mask_1314;
wire										   output_sign_1314;
wire[7:0]								   biased_exponent_1314;
wire										   op_exception_1314;
wire										   inf_nan_exception_1314;
wire[1:0]								   den_exception_1314;
wire[47:0]								   ma_1314;
wire[23:0]								   mb_1314;
wire										   res_1l_1314;
wire										   res_2l_1314;
wire										   res_3l_1314;
wire										   res_4l_1314;
wire										   res_5l_1314;
wire										   res_6l_1314;
wire										   res_7l_1314;
wire										   res_8l_1314;
wire										   res_9l_1314;
wire										   res_10l_1314;
wire										   res_11l_1314;
wire										   res_12l_1314;
wire										   res_13l_1314;
wire										   res_14l_1314;
wire										   res_15l_1314;
wire										   res_16l_1314;
wire										   res_17l_1314;
wire										   res_18l_1314;
wire										   res_19l_1314;
wire										   res_20l_1314;
wire										   res_21l_1314;
wire										   res_22l_1314;
wire										   res_23l_1314;
wire										   res_24l_1314;
wire										   res_25l_1314;
wire										   res_26l_1314;
wire[24:0]								   rp_26l_1314;
wire										   zero_1314;  
    // Seg_Reg_14//
wire                                           valid_1415;
wire										   mask_1415;
wire										   output_sign_1415;
wire[7:0]								   biased_exponent_1415;
wire										   op_exception_1415;
wire										   inf_nan_exception_1415;
wire[1:0]								   den_exception_1415;
wire[47:0]								   ma_1415;
wire[23:0]								   mb_1415;
wire										   res_1l_1415;
wire										   res_2l_1415;
wire										   res_3l_1415;
wire										   res_4l_1415;
wire										   res_5l_1415;
wire										   res_6l_1415;
wire										   res_7l_1415;
wire										   res_8l_1415;
wire										   res_9l_1415;
wire										   res_10l_1415;
wire										   res_11l_1415;
wire										   res_12l_1415;
wire										   res_13l_1415;
wire										   res_14l_1415;
wire										   res_15l_1415;
wire										   res_16l_1415;
wire										   res_17l_1415;
wire										   res_18l_1415;
wire										   res_19l_1415;
wire										   res_20l_1415;
wire										   res_21l_1415;
wire										   res_22l_1415;
wire										   res_23l_1415;
wire										   res_24l_1415;
wire										   res_25l_1415;
wire										   res_26l_1415;
wire										   res_27l_1415;
wire										   res_28l_1415;
wire[24:0]								   rp_28l_1415;
wire										   zero_1415;
    // Seg_Reg_15//
wire                                       valid_1516;
wire									   mask_1516;
wire									   output_sign_1516;
wire[7:0]							   biased_exponent_1516;
wire									   op_exception_1516;
wire									   inf_nan_exception_1516;
wire[1:0]							   den_exception_1516;
wire[47:0]							   ma_1516;
wire[23:0]							   mb_1516;
wire									   res_1l_1516;
wire									   res_2l_1516;
wire									   res_3l_1516;
wire									   res_4l_1516;
wire									   res_5l_1516;
wire									   res_6l_1516;
wire									   res_7l_1516;
wire									   res_8l_1516;
wire									   res_9l_1516;
wire									   res_10l_1516;
wire									   res_11l_1516;
wire									   res_12l_1516;
wire									   res_13l_1516;
wire									   res_14l_1516;
wire									   res_15l_1516;
wire									   res_16l_1516;
wire									   res_17l_1516;
wire									   res_18l_1516;
wire									   res_19l_1516;
wire									   res_20l_1516;
wire									   res_21l_1516;
wire									   res_22l_1516;
wire									   res_23l_1516;
wire									   res_24l_1516;
wire									   res_25l_1516;
wire									   res_26l_1516;
wire									   res_27l_1516;
wire									   res_28l_1516;
wire									   res_29l_1516;
wire									   res_30l_1516;
wire[24:0]							   rp_30l_1516;
wire									   zero_1516; 
    // Seg_Reg_16//
wire                                      valid_1617;
wire									   mask_1617;
wire									   output_sign_1617;
wire[7:0]							   biased_exponent_1617;
wire									   op_exception_1617;
wire									   inf_nan_exception_1617;
wire[1:0]							   den_exception_1617;
wire[47:0]							   ma_1617;
wire[23:0]							   mb_1617;
wire									   res_1l_1617;
wire									   res_2l_1617;
wire									   res_3l_1617;
wire									   res_4l_1617;
wire									   res_5l_1617;
wire									   res_6l_1617;
wire									   res_7l_1617;
wire									   res_8l_1617;
wire									   res_9l_1617;
wire									   res_10l_1617;
wire									   res_11l_1617;
wire									   res_12l_1617;
wire									   res_13l_1617;
wire									   res_14l_1617;
wire									   res_15l_1617;
wire									   res_16l_1617;
wire									   res_17l_1617;
wire									   res_18l_1617;
wire									   res_19l_1617;
wire									   res_20l_1617;
wire									   res_21l_1617;
wire									   res_22l_1617;
wire									   res_23l_1617;
wire									   res_24l_1617;
wire									   res_25l_1617;
wire									   res_26l_1617;
wire									   res_27l_1617;
wire									   res_28l_1617;
wire									   res_29l_1617;
wire									   res_30l_1617;
wire									   res_31l_1617;
wire									   res_32l_1617;
wire[24:0]							   rp_32l_1617;
wire									   zero_1617;
 // Seg_Reg_17//
wire                                           valid_1718;
wire										   mask_1718;
wire										   output_sign_1718;
wire[7:0]								   biased_exponent_1718;
wire										   op_exception_1718;
wire										   inf_nan_exception_1718;
wire[1:0]								   den_exception_1718;
wire[47:0]								   ma_1718;
wire[23:0]								   mb_1718;
wire										   res_1l_1718;
wire										   res_2l_1718;
wire										   res_3l_1718;
wire										   res_4l_1718;
wire										   res_5l_1718;
wire										   res_6l_1718;
wire										   res_7l_1718;
wire										   res_8l_1718;
wire										   res_9l_1718;
wire										   res_10l_1718;
wire										   res_11l_1718;
wire										   res_12l_1718;
wire										   res_13l_1718;
wire										   res_14l_1718;
wire										   res_15l_1718;
wire										   res_16l_1718;
wire										   res_17l_1718;
wire										   res_18l_1718;
wire										   res_19l_1718;
wire										   res_20l_1718;
wire										   res_21l_1718;
wire										   res_22l_1718;
wire										   res_23l_1718;
wire										   res_24l_1718;
wire										   res_25l_1718;
wire										   res_26l_1718;
wire										   res_27l_1718;
wire										   res_28l_1718;
wire										   res_29l_1718;
wire										   res_30l_1718;
wire										   res_31l_1718;
wire										   res_32l_1718;
wire										   res_33l_1718;
wire										   res_34l_1718;
wire[24:0]								   rp_34l_1718;
wire										   zero_1718;  
    // Seg_Reg_18//
wire                                       valid_1819;
wire									   mask_1819;
wire									   output_sign_1819;
wire[7:0]							   biased_exponent_1819;
wire									   op_exception_1819;
wire									   inf_nan_exception_1819;
wire[1:0]							   den_exception_1819;
wire[47:0]							   ma_1819;
wire[23:0]							   mb_1819;
wire									   res_1l_1819;
wire									   res_2l_1819;
wire									   res_3l_1819;
wire									   res_4l_1819;
wire									   res_5l_1819;
wire									   res_6l_1819;
wire									   res_7l_1819;
wire									   res_8l_1819;
wire									   res_9l_1819;
wire									   res_10l_1819;
wire									   res_11l_1819;
wire									   res_12l_1819;
wire									   res_13l_1819;
wire									   res_14l_1819;
wire									   res_15l_1819;
wire									   res_16l_1819;
wire									   res_17l_1819;
wire									   res_18l_1819;
wire									   res_19l_1819;
wire									   res_20l_1819;
wire									   res_21l_1819;
wire									   res_22l_1819;
wire									   res_23l_1819;
wire									   res_24l_1819;
wire									   res_25l_1819;
wire									   res_26l_1819;
wire									   res_27l_1819;
wire									   res_28l_1819;
wire									   res_29l_1819;
wire									   res_30l_1819;
wire									   res_31l_1819;
wire									   res_32l_1819;
wire									   res_33l_1819;
wire									   res_34l_1819;
wire									   res_35l_1819;
wire									   res_36l_1819;
wire[24:0]							   rp_36l_1819;
wire									   zero_1819; 
    // Seg_Reg_19//
wire                                       valid_1920;
wire									   mask_1920;
wire									   output_sign_1920;
wire[7:0]							   biased_exponent_1920;
wire									   op_exception_1920;
wire									   inf_nan_exception_1920;
wire[1:0]							   den_exception_1920;
wire[47:0]							   ma_1920;
wire[23:0]							   mb_1920;
wire									   res_1l_1920;
wire									   res_2l_1920;
wire									   res_3l_1920;
wire									   res_4l_1920;
wire									   res_5l_1920;
wire									   res_6l_1920;
wire									   res_7l_1920;
wire									   res_8l_1920;
wire									   res_9l_1920;
wire									   res_10l_1920;
wire									   res_11l_1920;
wire									   res_12l_1920;
wire									   res_13l_1920;
wire									   res_14l_1920;
wire									   res_15l_1920;
wire									   res_16l_1920;
wire									   res_17l_1920;
wire									   res_18l_1920;
wire									   res_19l_1920;
wire									   res_20l_1920;
wire									   res_21l_1920;
wire									   res_22l_1920;
wire									   res_23l_1920;
wire									   res_24l_1920;
wire									   res_25l_1920;
wire									   res_26l_1920;
wire									   res_27l_1920;
wire									   res_28l_1920;
wire									   res_29l_1920;
wire									   res_30l_1920;
wire									   res_31l_1920;
wire									   res_32l_1920;
wire									   res_33l_1920;
wire									   res_34l_1920;
wire									   res_35l_1920;
wire									   res_36l_1920;
wire									   res_37l_1920;
wire									   res_38l_1920;
wire[24:0]							   rp_38l_1920;
wire									   zero_1920;  
    // Seg_Reg_20//
wire                                       valid_2021;
wire									   mask_2021;
wire									   output_sign_2021;
wire[7:0]							   biased_exponent_2021;
wire									   op_exception_2021;
wire									   inf_nan_exception_2021;
wire[1:0]							   den_exception_2021;
wire[47:0]							   ma_2021;
wire[23:0]							   mb_2021;
wire									   res_1l_2021;
wire									   res_2l_2021;
wire									   res_3l_2021;
wire									   res_4l_2021;
wire									   res_5l_2021;
wire									   res_6l_2021;
wire									   res_7l_2021;
wire									   res_8l_2021;
wire									   res_9l_2021;
wire									   res_10l_2021;
wire									   res_11l_2021;
wire									   res_12l_2021;
wire									   res_13l_2021;
wire									   res_14l_2021;
wire									   res_15l_2021;
wire									   res_16l_2021;
wire									   res_17l_2021;
wire									   res_18l_2021;
wire									   res_19l_2021;
wire									   res_20l_2021;
wire									   res_21l_2021;
wire									   res_22l_2021;
wire									   res_23l_2021;
wire									   res_24l_2021;
wire									   res_25l_2021;
wire									   res_26l_2021;
wire									   res_27l_2021;
wire									   res_28l_2021;
wire									   res_29l_2021;
wire									   res_30l_2021;
wire									   res_31l_2021;
wire									   res_32l_2021;
wire									   res_33l_2021;
wire									   res_34l_2021;
wire									   res_35l_2021;
wire									   res_36l_2021;
wire									   res_37l_2021;
wire									   res_38l_2021;
wire									   res_39l_2021;
wire									   res_40l_2021;
wire[24:0]							   rp_40l_2021;
wire									   zero_2021;
    // Seg_Reg_21//
wire                                      valid_2122;
wire									   mask_2122;
wire									   output_sign_2122;
wire[7:0]							   biased_exponent_2122;
wire									   op_exception_2122;
wire									   inf_nan_exception_2122;
wire[1:0]							   den_exception_2122;
wire[47:0]							   ma_2122;
wire[23:0]							   mb_2122;
wire									   res_1l_2122;
wire									   res_2l_2122;
wire									   res_3l_2122;
wire									   res_4l_2122;
wire									   res_5l_2122;
wire									   res_6l_2122;
wire									   res_7l_2122;
wire									   res_8l_2122;
wire									   res_9l_2122;
wire									   res_10l_2122;
wire									   res_11l_2122;
wire									   res_12l_2122;
wire									   res_13l_2122;
wire									   res_14l_2122;
wire									   res_15l_2122;
wire									   res_16l_2122;
wire									   res_17l_2122;
wire									   res_18l_2122;
wire									   res_19l_2122;
wire									   res_20l_2122;
wire									   res_21l_2122;
wire									   res_22l_2122;
wire									   res_23l_2122;
wire									   res_24l_2122;
wire									   res_25l_2122;
wire									   res_26l_2122;
wire									   res_27l_2122;
wire									   res_28l_2122;
wire									   res_29l_2122;
wire									   res_30l_2122;
wire									   res_31l_2122;
wire									   res_32l_2122;
wire									   res_33l_2122;
wire									   res_34l_2122;
wire									   res_35l_2122;
wire									   res_36l_2122;
wire									   res_37l_2122;
wire									   res_38l_2122;
wire									   res_39l_2122;
wire									   res_40l_2122;
wire									   res_41l_2122;
wire									   res_42l_2122;
wire[24:0]							   rp_42l_2122;
wire									   zero_2122; 
    // Seg_Reg_22//
wire                                       valid_2223;
wire									   mask_2223;
wire									   output_sign_2223;
wire[7:0]  						       biased_exponent_2223;
wire									   op_exception_2223;
wire									   inf_nan_exception_2223;
wire[1:0]							   den_exception_2223;
wire[47:0]							   ma_2223;
wire[23:0]							   mb_2223;
wire									   res_1l_2223;
wire									   res_2l_2223;
wire									   res_3l_2223;
wire									   res_4l_2223;
wire									   res_5l_2223;
wire									   res_6l_2223;
wire									   res_7l_2223;
wire									   res_8l_2223;
wire									   res_9l_2223;
wire									   res_10l_2223;
wire									   res_11l_2223;
wire									   res_12l_2223;
wire									   res_13l_2223;
wire									   res_14l_2223;
wire									   res_15l_2223;
wire									   res_16l_2223;
wire									   res_17l_2223;
wire									   res_18l_2223;
wire									   res_19l_2223;
wire									   res_20l_2223;
wire									   res_21l_2223;
wire									   res_22l_2223;
wire									   res_23l_2223;
wire									   res_24l_2223;
wire									   res_25l_2223;
wire									   res_26l_2223;
wire									   res_27l_2223;
wire									   res_28l_2223;
wire									   res_29l_2223;
wire									   res_30l_2223;
wire									   res_31l_2223;
wire									   res_32l_2223;
wire									   res_33l_2223;
wire									   res_34l_2223;
wire									   res_35l_2223;
wire									   res_36l_2223;
wire									   res_37l_2223;
wire									   res_38l_2223;
wire									   res_39l_2223;
wire									   res_40l_2223;
wire									   res_41l_2223;
wire									   res_42l_2223;
wire									   res_43l_2223;
wire									   res_44l_2223;
wire[24:0]							   rp_44l_2223;
wire									   zero_2223; 
    // Seg_Reg_23//
wire                                          valid_2324;
wire										   mask_2324;
wire										   output_sign_2324;
wire[7:0]								   biased_exponent_2324;
wire										   op_exception_2324;
wire										   inf_nan_exception_2324;
wire[1:0]								   den_exception_2324;
wire[47:0]								   ma_2324;
wire[23:0]								   mb_2324;
wire [45:0]                              res_l;
wire[24:0]								   rp_46l_2324;
wire										   zero_2324;  
    
        /////////////////////////////////
       // INSTANCIACIONES //
      ////////////////////////////////
      
				  Exp_Sub sub (
										   // INPUTS //
										  .A(EA),
										  .B(EB),
										  // OUTPUTS //
										  .Difference(exponent_sub),
										  .flag_1_a(flag_1_a),
										  .flag_1_b(flag_1_b),
										  .flag_0_a(flag_0_a),
										  .flag_0_b(flag_0_b)
										  );
                              
      Int_DivisorLvl_24b lvl1(
                                          // INPUTS //
                                          .N(ma[47]),
                                          .D(mb),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(23'b0),
                                          .rp(rp_1l),
                                          .cout(cout_1l)
                                          );
                                          assign res_1l = cout_1l[23];                                    
      Int_DivisorLvl_24b lvl2(
                                          // INPUTS //
                                          .N(ma[46]),
                                          .D(mb),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_1l[22:0]),
                                          .rp(rp_2l),
                                          .cout(cout_2l)
                                          );
                                          assign res_2l = cout_2l[23];                                                   
                                                                
Seg_Reg#(.REG_SIZE(115))
										   seg_reg_01(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid,
										   mask,
										   SA,
										   SB,
										   exponent_sub,
										   flag_1_a,
										   flag_1_b,
										   flag_0_a,
										   flag_0_b,
										   ma,
										   mb,
										   res_1l,
										   res_2l,
										   rp_2l,
										   zero                      
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_12,
										   mask_12,
										   SA_12,
										   SB_12,
										   exponent_sub_12,
										   flag_1_a_12,
										   flag_1_b_12,
										   flag_0_a_12,
										   flag_0_b_12,
										   ma_12,
										   mb_12,
										   res_1l_12,
										   res_2l_12,
										   rp_2l_12,
										   zero_12  
										   })
										   );
                       
				Bias_Adder add(
										   // INPUTS //
										   .EA(exponent_sub_12),
										   .EB(8'd127),
										   // OUTPUTS //
										   .sum(biased_exponent),
										   .overflow(overflow1)
										   );  
										                                 
      Int_DivisorLvl_24b lvl3(
                                          // INPUTS //
                                          .N(ma_12[45]),
                                          .D(mb_12),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_2l_12[22:0]),
                                          .rp(rp_3l),
                                          .cout(cout_3l)
                                          );
                                          assign res_3l = cout_3l[23];   
                                            
      Int_DivisorLvl_24b lvl4(
                                          // INPUTS //
                                          .N(ma_12[44]),
                                          .D(mb_12),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_3l[22:0]),
                                          .rp(rp_4l),
                                          .cout(cout_4l)
                                          );
                                          assign res_4l = cout_4l[23];
                                          
 Seg_Reg#(.REG_SIZE(118))
										   seg_reg_02(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_12,
										   mask_12,
										   SA_12,
										   SB_12,
										   biased_exponent,
										   flag_1_a_12,
										   flag_1_b_12,
										   flag_0_a_12,
										   flag_0_b_12,
										   overflow1,
										   ma_12,
										   mb_12,
										   res_1l_12,
										   res_2l_12,
										   res_3l,
										   res_4l,										   
										   rp_4l,
										   zero_12                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_23,
										   mask_23,
										   SA_23,
										   SB_23,
										   biased_exponent_23,
										   flag_1_a_23,
										   flag_1_b_23,
										   flag_0_a_23,
										   flag_0_b_23,
										   overflow1_23,
										   ma_23,
										   mb_23,
										   res_1l_23,
										   res_2l_23,
										   res_3l_23,
										   res_4l_23,
										   rp_4l_23,
										   zero_23  
										   })
										   );
										   
Control_Unit_div control  (
                                           // INPUTS //
                                           .SA(SA_23),
                                           .SB(SB_23),
                                           .flag_1_a(flag_1_a_23),
                                           .flag_1_b(flag_1_b_23),
                                           .flag_0_a(flag_0_a_23),
                                           .flag_0_b(flag_0_b_23),
                                           .overflow(overflow1_23),
                                           // OUTPUTS //
                                           .output_sign(output_sign),
                                           .inf_nan_exception(inf_nan_exception),
                                           .op_exception(op_exception),
                                           .den_exception(den_exception)
                                           );
 Int_DivisorLvl_24b lvl5(
                                          // INPUTS //
                                          .N(ma_23[43]),
                                          .D(mb_23),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_4l_23[22:0]),
                                          .rp(rp_5l),
                                          .cout(cout_5l)
                                          );
                                          assign res_5l = cout_5l[23];    
                                                                                 
  Int_DivisorLvl_24b lvl6(
                                          // INPUTS //
                                          .N(ma_23[42]),
                                          .D(mb_23),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_5l[22:0]),
                                          .rp(rp_6l),
                                          .cout(cout_6l)
                                          );
                                          assign res_6l = cout_6l[23];
                                          
  Seg_Reg#(.REG_SIZE(118))
										   seg_reg_03(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_23,
										   mask_23,
										   output_sign,
										   biased_exponent_23,
										   op_exception,
										   inf_nan_exception,
										   den_exception,
										   ma_23,
										   mb_23,
										   res_1l_23,
										   res_2l_23,
										   res_3l_23,
										   res_4l_23,
										   res_5l,
										   res_6l,									   
										   rp_6l,
										   zero                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_34,
										   mask_34,
										   output_sign_34,
										   biased_exponent_34,
										   op_exception_34,
										   inf_nan_exception_34,
										   den_exception_34,
										   ma_34,
										   mb_34,
										   res_1l_34,
										   res_2l_34,
										   res_3l_34,
										   res_4l_34,
										   res_5l_34,
										   res_6l_34,
										   rp_6l_34,
										   zero_34  
										   })
										   );
  Int_DivisorLvl_24b lvl7(
                                          // INPUTS //
                                          .N(ma_34[41]),
                                          .D(mb_34),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_6l_34[22:0]),
                                          .rp(rp_7l),
                                          .cout(cout_7l)
                                          );
                                          assign res_7l = cout_7l[23];
  Int_DivisorLvl_24b lvl8(
                                          // INPUTS //
                                          .N(ma_34[40]),
                                          .D(mb_34),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_7l[22:0]),
                                          .rp(rp_8l),
                                          .cout(cout_8l)
                                          );
                                          assign res_8l = cout_8l[23]; 
                                                                                   										    
  Seg_Reg#(.REG_SIZE(120))
										   seg_reg_04(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_34,
										   mask_34,
										   output_sign_34,
										   biased_exponent_34,
										   op_exception_34,
										   inf_nan_exception_34,
										   den_exception_34,
										   ma_34,
										   mb_34,
										   res_1l_34,
										   res_2l_34,
										   res_3l_34,
										   res_4l_34,
										   res_5l_34,
										   res_6l_34,
										   res_7l,
										   res_8l,									   
										   rp_8l,
										   zero_34                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_45,
										   mask_45,
										   output_sign_45,
										   biased_exponent_45,
										   op_exception_45,
										   inf_nan_exception_45,
										   den_exception_45,
										   ma_45,
										   mb_45,
										   res_1l_45,
										   res_2l_45,
										   res_3l_45,
										   res_4l_45,
										   res_5l_45,
										   res_6l_45,
										   res_7l_45,
										   res_8l_45,
										   rp_8l_45,
										   zero_45  
										   })
										   );
										   										   
  Int_DivisorLvl_24b lvl9(
                                          // INPUTS //
                                          .N(ma_45[39]),
                                          .D(mb_45),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_8l_45[22:0]),
                                          .rp(rp_9l),
                                          .cout(cout_9l)
                                          );
                                          assign res_9l = cout_9l[23];		
                                         
   Int_DivisorLvl_24b lvl10(
                                          // INPUTS //
                                          .N(ma_45[38]),
                                          .D(mb_45),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_9l[22:0]),
                                          .rp(rp_10l),
                                          .cout(cout_10l)
                                          );
                                          assign res_10l = cout_10l[23];
                                          
   Seg_Reg#(.REG_SIZE(122))
										   seg_reg_05(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_45,
										   mask_45,
										   output_sign_45,
										   biased_exponent_45,
										   op_exception_45,
										   inf_nan_exception_45,
										   den_exception_45,
										   ma_45,
										   mb_45,
										   res_1l_45,
										   res_2l_45,
										   res_3l_45,
										   res_4l_45,
										   res_5l_45,
										   res_6l_45,
										   res_7l_45,
										   res_8l_45,
										   res_9l,
										   res_10l,								   
										   rp_10l,
										   zero_45                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_56,
										   mask_56,
										   output_sign_56,
										   biased_exponent_56,
										   op_exception_56,
										   inf_nan_exception_56,
										   den_exception_56,
										   ma_56,
										   mb_56,
										   res_1l_56,
										   res_2l_56,
										   res_3l_56,
										   res_4l_56,
										   res_5l_56,
										   res_6l_56,
										   res_7l_56,
										   res_8l_56,
										   res_9l_56,
										   res_10l_56,
										   rp_10l_56,
										   zero_56  
										   })
										   );  
 Int_DivisorLvl_24b lvl11(
                                          // INPUTS //
                                          .N(ma_56[37]),
                                          .D(mb_56),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_10l_56[22:0]),
                                          .rp(rp_11l),
                                          .cout(cout_11l)
                                          );
                                          assign res_11l = cout_11l[23];
                                          
  Int_DivisorLvl_24b lvl12(
                                          // INPUTS //
                                          .N(ma_56[36]),
                                          .D(mb_56),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_11l[22:0]),
                                          .rp(rp_12l),
                                          .cout(cout_12l)
                                          );
                                          assign res_12l = cout_12l[23];
                                          
    Seg_Reg#(.REG_SIZE(124))
										   seg_reg_06(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_56,
										   mask_56,
										   output_sign_56,
										   biased_exponent_56,
										   op_exception_56,
										   inf_nan_exception_56,
										   den_exception_56,
										   ma_56,
										   mb_56,
										   res_1l_56,
										   res_2l_56,
										   res_3l_56,
										   res_4l_56,
										   res_5l_56,
										   res_6l_56,
										   res_7l_56,
										   res_8l_56,
										   res_9l_56,
										   res_10l_56,
										   res_11l,
										   res_12l,								   
										   rp_12l,
										   zero_56                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_67,
										   mask_67,
										   output_sign_67,
										   biased_exponent_67,
										   op_exception_67,
										   inf_nan_exception_67,
										   den_exception_67,
										   ma_67,
										   mb_67,
										   res_1l_67,
										   res_2l_67,
										   res_3l_67,
										   res_4l_67,
										   res_5l_67,
										   res_6l_67,
										   res_7l_67,
										   res_8l_67,
										   res_9l_67,
										   res_10l_67,
										   res_11l_67,
										   res_12l_67,
										   rp_12l_67,
										   zero_67  
										   })
										   );
										   
  Int_DivisorLvl_24b lvl13(
                                          // INPUTS //
                                          .N(ma_67[35]),
                                          .D(mb_67),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_12l_67[22:0]),
                                          .rp(rp_13l),
                                          .cout(cout_13l)
                                          );
                                          assign res_13l = cout_13l[23];
                                          
 Int_DivisorLvl_24b lvl14(
                                          // INPUTS //
                                          .N(ma_67[34]),
                                          .D(mb_67),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_13l[22:0]),
                                          .rp(rp_14l),
                                          .cout(cout_14l)
                                          );
                                          assign res_14l = cout_14l[23];		
                                          
    Seg_Reg#(.REG_SIZE(126))
										   seg_reg_07(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_67,
										   mask_67,
										   output_sign_67,
										   biased_exponent_67,
										   op_exception_67,
										   inf_nan_exception_67,
										   den_exception_67,
										   ma_67,
										   mb_67,
										   res_1l_67,
										   res_2l_67,
										   res_3l_67,
										   res_4l_67,
										   res_5l_67,
										   res_6l_67,
										   res_7l_67,
										   res_8l_67,
										   res_9l_67,
										   res_10l_67,
										   res_11l_67,
										   res_12l_67,
										   res_13l,
										   res_14l,								   
										   rp_14l,
										   zero_67                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_78,
										   mask_78,
										   output_sign_78,
										   biased_exponent_78,
										   op_exception_78,
										   inf_nan_exception_78,
										   den_exception_78,
										   ma_78,
										   mb_78,
										   res_1l_78,
										   res_2l_78,
										   res_3l_78,
										   res_4l_78,
										   res_5l_78,
										   res_6l_78,
										   res_7l_78,
										   res_8l_78,
										   res_9l_78,
										   res_10l_78,
										   res_11l_78,
										   res_12l_78,
										   res_13l_78,
										   res_14l_78,
										   rp_14l_78,
										   zero_78  
										   })
										   );
										   
 Int_DivisorLvl_24b lvl15(
                                          // INPUTS //
                                          .N(ma_78[33]),
                                          .D(mb_78),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_14l_78[22:0]),
                                          .rp(rp_15l),
                                          .cout(cout_15l)
                                          );
                                          assign res_15l = cout_15l[23];	
                                 
  Int_DivisorLvl_24b lvl16(
                                          // INPUTS //
                                          .N(ma_78[32]),
                                          .D(mb_78),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_15l[22:0]),
                                          .rp(rp_16l),
                                          .cout(cout_16l)
                                          );
                                          assign res_16l = cout_16l[23];	 
                                          
    Seg_Reg#(.REG_SIZE(128))
										   seg_reg_08(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_78,
										   mask_78,
										   output_sign_78,
										   biased_exponent_78,
										   op_exception_78,
										   inf_nan_exception_78,
										   den_exception_78,
										   ma_78,
										   mb_78,
										   res_1l_78,        
										   res_2l_78,
										   res_3l_78,
										   res_4l_78,
										   res_5l_78,
										   res_6l_78,
										   res_7l_78,
										   res_8l_78,
										   res_9l_78,
										   res_10l_78,
										   res_11l_78,
										   res_12l_78,
										   res_13l_78,
										   res_14l_78,
										   res_15l,
										   res_16l,							   
										   rp_16l,
										   zero_78                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_89,
										   mask_89,
										   output_sign_89,
										   biased_exponent_89,
										   op_exception_89,
										   inf_nan_exception_89,
										   den_exception_89,
										   ma_89,
										   mb_89,
										   res_1l_89,
										   res_2l_89,
										   res_3l_89,
										   res_4l_89,
										   res_5l_89,
										   res_6l_89,
										   res_7l_89,
										   res_8l_89,
										   res_9l_89,
										   res_10l_89,
										   res_11l_89,
										   res_12l_89,
										   res_13l_89,
										   res_14l_89,
										   res_15l_89,
										   res_16l_89,
										   rp_16l_89,
										   zero_89  
										   })
										   );
  Int_DivisorLvl_24b lvl17(
                                          // INPUTS //
                                          .N(ma_89[31]),
                                          .D(mb_89),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_16l_89[22:0]),
                                          .rp(rp_17l),
                                          .cout(cout_17l)
                                          );
                                          assign res_17l = cout_17l[23];
                                          
  Int_DivisorLvl_24b lvl18(
                                          // INPUTS //
                                          .N(ma_89[30]),
                                          .D(mb_89),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_17l[22:0]),
                                          .rp(rp_18l),
                                          .cout(cout_18l)
                                          );
                                          assign res_18l = cout_18l[23];
                                          
     Seg_Reg#(.REG_SIZE(130))
										   seg_reg_09(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_89,
										   mask_89,
										   output_sign_89,
										   biased_exponent_89,
										   op_exception_89,
										   inf_nan_exception_89,
										   den_exception_89,
										   ma_89,
										   mb_89,
										   res_1l_89,
										   res_2l_89,
										   res_3l_89,
										   res_4l_89,
										   res_5l_89,
										   res_6l_89,
										   res_7l_89,
										   res_8l_89,
										   res_9l_89,
										   res_10l_89,
										   res_11l_89,
										   res_12l_89,
										   res_13l_89,
										   res_14l_89,
										   res_15l_89,
										   res_16l_89,
										   res_17l,
										   res_18l,						   
										   rp_18l,
										   zero_89                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_910,
										   mask_910,
										   output_sign_910,
										   biased_exponent_910,
										   op_exception_910,
										   inf_nan_exception_910,
										   den_exception_910,
										   ma_910,
										   mb_910,
										   res_1l_910,
										   res_2l_910,
										   res_3l_910,
										   res_4l_910,
										   res_5l_910,
										   res_6l_910,
										   res_7l_910,
										   res_8l_910,
										   res_9l_910,
										   res_10l_910,
										   res_11l_910,
										   res_12l_910,
										   res_13l_910,
										   res_14l_910,
										   res_15l_910,
										   res_16l_910,
										   res_17l_910,
										   res_18l_910,
										   rp_18l_910,
										   zero_910  
										   })
										   );
										   
  Int_DivisorLvl_24b lvl19(
                                          // INPUTS //
                                          .N(ma_910[29]),
                                          .D(mb_910),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_18l_910[22:0]),
                                          .rp(rp_19l),
                                          .cout(cout_19l)
                                          );
                                          assign res_19l = cout_19l[23];		
                                          
  Int_DivisorLvl_24b lvl20(
                                          // INPUTS //
                                          .N(ma_910[28]),
                                          .D(mb_910),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_19l[22:0]),
                                          .rp(rp_20l),
                                          .cout(cout_20l)
                                          );
                                          assign res_20l = cout_20l[23];
                                          
      Seg_Reg#(.REG_SIZE(132))
										   seg_reg_10(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_910,
										   mask_910,
										   output_sign_910,
										   biased_exponent_910,
										   op_exception_910,
										   inf_nan_exception_910,
										   den_exception_910,
										   ma_910,
										   mb_910,
										   res_1l_910,
										   res_2l_910,
										   res_3l_910,
										   res_4l_910,
										   res_5l_910,
										   res_6l_910,
										   res_7l_910,
										   res_8l_910,
										   res_9l_910,
										   res_10l_910,
										   res_11l_910,
										   res_12l_910,
										   res_13l_910,
										   res_14l_910,
										   res_15l_910,
										   res_16l_910,
										   res_17l_910,
										   res_18l_910,
										   res_19l,
										   res_20l,					   
										   rp_20l,
										   zero_910                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_1011,
										   mask_1011,
										   output_sign_1011,
										   biased_exponent_1011,
										   op_exception_1011,
										   inf_nan_exception_1011,
										   den_exception_1011,
										   ma_1011,
										   mb_1011,
										   res_1l_1011,
										   res_2l_1011,
										   res_3l_1011,
										   res_4l_1011,
										   res_5l_1011,
										   res_6l_1011,
										   res_7l_1011,
										   res_8l_1011,
										   res_9l_1011,
										   res_10l_1011,
										   res_11l_1011,
										   res_12l_1011,
										   res_13l_1011,
										   res_14l_1011,
										   res_15l_1011,
										   res_16l_1011,
										   res_17l_1011,
										   res_18l_1011,
										   res_19l_1011,
										   res_20l_1011,
										   rp_20l_1011,
										   zero_1011  
										   })
										   );
										   
  Int_DivisorLvl_24b lvl21(
                                          // INPUTS //
                                          .N(ma_1011[27]),
                                          .D(mb_1011),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_20l_1011[22:0]),
                                          .rp(rp_21l),
                                          .cout(cout_21l)
                                          );
                                          assign res_21l = cout_21l[23];	
                                          
   Int_DivisorLvl_24b lvl22(
                                          // INPUTS //
                                          .N(ma_1011[26]),
                                          .D(mb_1011),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_21l[22:0]),
                                          .rp(rp_22l),
                                          .cout(cout_22l)
                                          );
                                          assign res_22l = cout_22l[23];
                                          
 Seg_Reg#(.REG_SIZE(134))
										   seg_reg_11(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_1011,
										   mask_1011,
										   output_sign_1011,
										   biased_exponent_1011,
										   op_exception_1011,
										   inf_nan_exception_1011,
										   den_exception_1011,
										   ma_1011,
										   mb_1011,
										   res_1l_1011,
										   res_2l_1011,
										   res_3l_1011,
										   res_4l_1011,
										   res_5l_1011,
										   res_6l_1011,
										   res_7l_1011,
										   res_8l_1011,
										   res_9l_1011,
										   res_10l_1011,
										   res_11l_1011,
										   res_12l_1011,
										   res_13l_1011,
										   res_14l_1011,
										   res_15l_1011,
										   res_16l_1011,
										   res_17l_1011,
										   res_18l_1011	,
										   res_19l_1011,
										   res_20l_1011,
										   res_21l,
										   res_22l,					   
										   rp_22l,
										   zero_1011                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_1112,
										   mask_1112,
										   output_sign_1112,
										   biased_exponent_1112,
										   op_exception_1112,
										   inf_nan_exception_1112,
										   den_exception_1112,
										   ma_1112,
										   mb_1112,
										   res_1l_1112,
										   res_2l_1112,
										   res_3l_1112,
										   res_4l_1112,
										   res_5l_1112,
										   res_6l_1112,
										   res_7l_1112,
										   res_8l_1112,
										   res_9l_1112,
										   res_10l_1112,
										   res_11l_1112,
										   res_12l_1112,
										   res_13l_1112,
										   res_14l_1112,
										   res_15l_1112,
										   res_16l_1112,
										   res_17l_1112,
										   res_18l_1112,
										   res_19l_1112,
										   res_20l_1112,
										   res_21l_1112,
										   res_22l_1112,
										   rp_22l_1112,
										   zero_1112  
										   })
										   );
										   
 Int_DivisorLvl_24b lvl23(
                                          // INPUTS //
                                          .N(ma_1112[25]),
                                          .D(mb_1112),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_22l_1112[22:0]),
                                          .rp(rp_23l),
                                          .cout(cout_23l)
                                          );
                                          assign res_23l = cout_23l[23];	
                                          
 Int_DivisorLvl_25b lvl24(
                                          // INPUTS //
                                          .N(ma_1112[24]),
                                          .D(mb_1112),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_23l),
                                          .rp(rp_24l),
                                          .cout(cout_24l)
                                          );
                                          assign res_24l = cout_24l[24];
                                          
  Seg_Reg#(.REG_SIZE(137))
										   seg_reg_12(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_1112,
										   mask_1112,
										   output_sign_1112,
										   biased_exponent_1112,
										   op_exception_1112,
										   inf_nan_exception_1112,
										   den_exception_1112,
										   ma_1112,
										   mb_1112,
										   res_1l_1112,
										   res_2l_1112,
										   res_3l_1112,
										   res_4l_1112,
										   res_5l_1112,
										   res_6l_1112,
										   res_7l_1112,
										   res_8l_1112,
										   res_9l_1112,
										   res_10l_1112,
										   res_11l_1112,
										   res_12l_1112,
										   res_13l_1112,
										   res_14l_1112,
										   res_15l_1112,
										   res_16l_1112,
										   res_17l_1112,
										   res_18l_1112,
										   res_19l_1112,
										   res_20l_1112,
										   res_21l_1112,
										   res_22l_1112,
										   res_23l,
										   res_24l,					   
										   rp_24l,
										   zero                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_1213,
										   mask_1213,
										   output_sign_1213,
										   biased_exponent_1213,
										   op_exception_1213,
										   inf_nan_exception_1213,
										   den_exception_1213,
										   ma_1213,
										   mb_1213,
										   res_1l_1213,
										   res_2l_1213,
										   res_3l_1213,
										   res_4l_1213,
										   res_5l_1213,
										   res_6l_1213,
										   res_7l_1213,
										   res_8l_1213,
										   res_9l_1213,
										   res_10l_1213,
										   res_11l_1213,
										   res_12l_1213,
										   res_13l_1213,
										   res_14l_1213,
										   res_15l_1213,
										   res_16l_1213,
										   res_17l_1213,
										   res_18l_1213,
										   res_19l_1213,
										   res_20l_1213,
										   res_21l_1213,
										   res_22l_1213,
										   res_23l_1213,
										   res_24l_1213,
										   rp_24l_1213,
										   zero_1213  
										   })
										   );
										   
 Int_DivisorLvl_25b lvl25(
                                          // INPUTS //
                                          .N(ma_1213[23]),
                                          .D(mb_1213),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_24l_1213[23:0]),
                                          .rp(rp_25l),
                                          .cout(cout_25l)
                                          );
                                          assign res_25l = cout_25l[24];
 Int_DivisorLvl_25b lvl26(
                                          // INPUTS //
                                          .N(ma_1213[22]),
                                          .D(mb_1213),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_25l[23:0]),
                                          .rp(rp_26l),
                                          .cout(cout_26l)
                                          );
                                          assign res_26l = cout_26l[24];
                                          
  Seg_Reg#(.REG_SIZE(139))
										   seg_reg_13(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_1213,
										   mask_1213,
										   output_sign_1213,
										   biased_exponent_1213,
										   op_exception_1213,
										   inf_nan_exception_1213,
										   den_exception_1213,
										   ma_1213,
										   mb_1213,
										   res_1l_1213,
										   res_2l_1213,
										   res_3l_1213,
										   res_4l_1213,
										   res_5l_1213,
										   res_6l_1213,
										   res_7l_1213,
										   res_8l_1213,
										   res_9l_1213,
										   res_10l_1213	,
										   res_11l_1213,
										   res_12l_1213,
										   res_13l_1213,
										   res_14l_1213,
										   res_15l_1213,
										   res_16l_1213,
										   res_17l_1213,
										   res_18l_1213	,
										   res_19l_1213,
										   res_20l_1213,
										   res_21l_1213,
										   res_22l_1213,
										   res_23l_1213,
										   res_24l_1213,
										   res_25l,
										   res_26l,				   
										   rp_26l,
										   zero_1213                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_1314,
										   mask_1314,
										   output_sign_1314,
										   biased_exponent_1314,
										   op_exception_1314,
										   inf_nan_exception_1314,
										   den_exception_1314,
										   ma_1314,
										   mb_1314,
										   res_1l_1314,
										   res_2l_1314,
										   res_3l_1314,
										   res_4l_1314,
										   res_5l_1314,
										   res_6l_1314,
										   res_7l_1314,
										   res_8l_1314,
										   res_9l_1314,
										   res_10l_1314,
										   res_11l_1314,
										   res_12l_1314,
										   res_13l_1314,
										   res_14l_1314,
										   res_15l_1314,
										   res_16l_1314,
										   res_17l_1314,
										   res_18l_1314,
										   res_19l_1314,
										   res_20l_1314,
										   res_21l_1314,
										   res_22l_1314,
										   res_23l_1314,
										   res_24l_1314,
										   res_25l_1314,
										   res_26l_1314,
										   rp_26l_1314,
										   zero_1314  
										   })
										   );
										   
 Int_DivisorLvl_25b lvl27(
                                          // INPUTS //
                                          .N(ma_1314[21]),
                                          .D(mb_1314),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_26l_1314[23:0]),
                                          .rp(rp_27l),
                                          .cout(cout_27l)
                                          );
                                          assign res_27l = cout_27l[24];
 Int_DivisorLvl_25b lvl28(
                                          // INPUTS //
                                          .N(ma_1314[20]),
                                          .D(mb_1314),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_27l[23:0]),
                                          .rp(rp_28l),
                                          .cout(cout_28l)
                                          );
                                          assign res_28l = cout_28l[24];
                                          
  Seg_Reg#(.REG_SIZE(141))
										   seg_reg_14(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_1314,
										   mask_1314,
										   output_sign_1314,
										   biased_exponent_1314,
										   op_exception_1314,
										   inf_nan_exception_1314,
										   den_exception_1314,
										   ma_1314,
										   mb_1314,
										   res_1l_1314,
										   res_2l_1314,
										   res_3l_1314,
										   res_4l_1314,
										   res_5l_1314,
										   res_6l_1314,
										   res_7l_1314,
										   res_8l_1314,
										   res_9l_1314,
										   res_10l_1314,
										   res_11l_1314,
										   res_12l_1314,
										   res_13l_1314,
										   res_14l_1314,
										   res_15l_1314,
										   res_16l_1314,
										   res_17l_1314,
										   res_18l_1314,
										   res_19l_1314,
										   res_20l_1314,
										   res_21l_1314,
										   res_22l_1314,
										   res_23l_1314,
										   res_24l_1314,
										   res_25l_1314,
										   res_26l_1314,
										   res_27l,
										   res_28l,				   
										   rp_28l,
										   zero_1314                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_1415,
										   mask_1415,
										   output_sign_1415,
										   biased_exponent_1415,
										   op_exception_1415,
										   inf_nan_exception_1415,
										   den_exception_1415,
										   ma_1415,
										   mb_1415,
										   res_1l_1415,
										   res_2l_1415,
										   res_3l_1415,
										   res_4l_1415,
										   res_5l_1415,
										   res_6l_1415,
										   res_7l_1415,
										   res_8l_1415,
										   res_9l_1415,
										   res_10l_1415,
										   res_11l_1415,
										   res_12l_1415,
										   res_13l_1415,
										   res_14l_1415,
										   res_15l_1415,
										   res_16l_1415,
										   res_17l_1415,
										   res_18l_1415,
										   res_19l_1415,
										   res_20l_1415,
										   res_21l_1415,
										   res_22l_1415,
										   res_23l_1415,
										   res_24l_1415,
										   res_25l_1415,
										   res_26l_1415,
										   res_27l_1415,
										   res_28l_1415,
										   rp_28l_1415,
										   zero_1415  
										   })
										   );
										   
 Int_DivisorLvl_25b lvl29(
                                          // INPUTS //
                                          .N(ma_1415[19]),
                                          .D(mb_1415),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_28l_1415[23:0]),
                                          .rp(rp_29l),
                                          .cout(cout_29l)
                                          );
                                          assign res_29l = cout_29l[24];
                                          
 Int_DivisorLvl_25b lvl30(
                                          // INPUTS //
                                          .N(ma_1415[18]),
                                          .D(mb_1415),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_29l[23:0]),
                                          .rp(rp_30l),
                                          .cout(cout_30l)
                                          );
                                          assign res_30l = cout_30l[24];
                                          
Seg_Reg#(.REG_SIZE(143))
										   seg_reg_15(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_1415,
										   mask_1415,
										   output_sign_1415,
										   biased_exponent_1415,
										   op_exception_1415,
										   inf_nan_exception_1415,
										   den_exception_1415,
										   ma_1415,
										   mb_1415,
										   res_1l_1415,
										   res_2l_1415,
										   res_3l_1415,
										   res_4l_1415,
										   res_5l_1415,
										   res_6l_1415,
										   res_7l_1415,
										   res_8l_1415,
										   res_9l_1415,
										   res_10l_1415,
										   res_11l_1415,
										   res_12l_1415,
										   res_13l_1415,
										   res_14l_1415,
										   res_15l_1415,
										   res_16l_1415,
										   res_17l_1415,
										   res_18l_1415,
										   res_19l_1415,
										   res_20l_1415,
										   res_21l_1415,
										   res_22l_1415,
										   res_23l_1415,
										   res_24l_1415,
										   res_25l_1415,
										   res_26l_1415,
										   res_27l_1415,
										   res_28l_1415,
										   res_29l,
										   res_30l,				   
										   rp_30l,
										   zero_1415                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_1516,
										   mask_1516,
										   output_sign_1516,
										   biased_exponent_1516,
										   op_exception_1516,
										   inf_nan_exception_1516,
										   den_exception_1516,
										   ma_1516,
										   mb_1516,
										   res_1l_1516,
										   res_2l_1516,
										   res_3l_1516,
										   res_4l_1516,
										   res_5l_1516,
										   res_6l_1516,
										   res_7l_1516,
										   res_8l_1516,
										   res_9l_1516,
										   res_10l_1516,
										   res_11l_1516,
										   res_12l_1516,
										   res_13l_1516,
										   res_14l_1516,
										   res_15l_1516,
										   res_16l_1516,
										   res_17l_1516,
										   res_18l_1516,
										   res_19l_1516,
										   res_20l_1516,
										   res_21l_1516,
										   res_22l_1516,
										   res_23l_1516,
										   res_24l_1516,
										   res_25l_1516,
										   res_26l_1516,
										   res_27l_1516,
										   res_28l_1516,
										   res_29l_1516,
										   res_30l_1516,
										   rp_30l_1516,
										   zero_1516  
										   })
										   );    
										   
 Int_DivisorLvl_25b lvl31(
                                          // INPUTS //
                                          .N(ma_1516[17]),
                                          .D(mb_1516),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_30l_1516[23:0]),
                                          .rp(rp_31l),
                                          .cout(cout_31l)
                                          );
                                          assign res_31l = cout_31l[24];
                                          
 Int_DivisorLvl_25b lvl32(
                                          // INPUTS //
                                          .N(ma_1516[16]),
                                          .D(mb_1516),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_31l[23:0]),
                                          .rp(rp_32l),
                                          .cout(cout_32l)
                                          );
                                          assign res_32l = cout_32l[24];
                                          
Seg_Reg#(.REG_SIZE(145))
										   seg_reg_16(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_1516,
										   mask_1516,
										   output_sign_1516,
										   biased_exponent_1516,
										   op_exception_1516,
										   inf_nan_exception_1516,
										   den_exception_1516,
										   ma_1516,
										   mb_1516,
										   res_1l_1516,
										   res_2l_1516,
										   res_3l_1516,
										   res_4l_1516,
										   res_5l_1516,
										   res_6l_1516,
										   res_7l_1516,
										   res_8l_1516,
										   res_9l_1516,
										   res_10l_1516	,
										   res_11l_1516,
										   res_12l_1516,
										   res_13l_1516,
										   res_14l_1516,
										   res_15l_1516,
										   res_16l_1516,
										   res_17l_1516,
										   res_18l_1516	,
										   res_19l_1516,
										   res_20l_1516,
										   res_21l_1516,
										   res_22l_1516,
										   res_23l_1516,
										   res_24l_1516,
										   res_25l_1516,
										   res_26l_1516,
										   res_27l_1516,
										   res_28l_1516,
										   res_29l_1516,
										   res_30l_1516,
										   res_31l,
										   res_32l,				   
										   rp_32l,
										   zero_1516                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_1617,
										   mask_1617,
										   output_sign_1617,
										   biased_exponent_1617,
										   op_exception_1617,
										   inf_nan_exception_1617,
										   den_exception_1617,
										   ma_1617,
										   mb_1617,
										   res_1l_1617,
										   res_2l_1617,
										   res_3l_1617,
										   res_4l_1617,
										   res_5l_1617,
										   res_6l_1617,
										   res_7l_1617,
										   res_8l_1617,
										   res_9l_1617,
										   res_10l_1617,
										   res_11l_1617,
										   res_12l_1617,
										   res_13l_1617,
										   res_14l_1617,
										   res_15l_1617,
										   res_16l_1617,
										   res_17l_1617,
										   res_18l_1617,
										   res_19l_1617,
										   res_20l_1617,
										   res_21l_1617,
										   res_22l_1617,
										   res_23l_1617,
										   res_24l_1617,
										   res_25l_1617,
										   res_26l_1617,
										   res_27l_1617,
										   res_28l_1617,
										   res_29l_1617,
										   res_30l_1617,
										   res_31l_1617,
										   res_32l_1617,
										   rp_32l_1617,
										   zero_1617  
										   })
										   );                                           
                                          
  Int_DivisorLvl_25b lvl33(
                                          // INPUTS //
                                          .N(ma_1617[15]),
                                          .D(mb_1617),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_32l_1617[23:0]),
                                          .rp(rp_33l),
                                          .cout(cout_33l)
                                          );
                                          assign res_33l = cout_33l[24];
                                          
 Int_DivisorLvl_25b lvl34(
                                          // INPUTS //
                                          .N(ma_1617[14]),
                                          .D(mb_1617),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_33l[23:0]),
                                          .rp(rp_34l),
                                          .cout(cout_34l)
                                          );
                                          assign res_34l = cout_34l[24];
                                          
 Seg_Reg#(.REG_SIZE(147))
										   seg_reg_17(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_1617,
										   mask_1617,
										   output_sign_1617,
										   biased_exponent_1617,
										   op_exception_1617,
										   inf_nan_exception_1617,
										   den_exception_1617,
										   ma_1617,
										   mb_1617,
										   res_1l_1617,
										   res_2l_1617,
										   res_3l_1617,
										   res_4l_1617,
										   res_5l_1617,
										   res_6l_1617,
										   res_7l_1617,
										   res_8l_1617,
										   res_9l_1617,
										   res_10l_1617	,
										   res_11l_1617,
										   res_12l_1617,
										   res_13l_1617,
										   res_14l_1617,
										   res_15l_1617,
										   res_16l_1617,
										   res_17l_1617,
										   res_18l_1617	,
										   res_19l_1617,
										   res_20l_1617,
										   res_21l_1617,
										   res_22l_1617,
										   res_23l_1617,
										   res_24l_1617,
										   res_25l_1617,
										   res_26l_1617,
										   res_27l_1617,
										   res_28l_1617,
										   res_29l_1617,
										   res_30l_1617,
										   res_31l_1617,
										   res_32l_1617,
										   res_33l,
										   res_34l,				   
										   rp_34l,
										   zero_1617                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_1718,
										   mask_1718,
										   output_sign_1718,
										   biased_exponent_1718,
										   op_exception_1718,
										   inf_nan_exception_1718,
										   den_exception_1718,
										   ma_1718,
										   mb_1718,
										   res_1l_1718,
										   res_2l_1718,
										   res_3l_1718,
										   res_4l_1718,
										   res_5l_1718,
										   res_6l_1718,
										   res_7l_1718,
										   res_8l_1718,
										   res_9l_1718,
										   res_10l_1718,
										   res_11l_1718,
										   res_12l_1718,
										   res_13l_1718,
										   res_14l_1718,
										   res_15l_1718,
										   res_16l_1718,
										   res_17l_1718,
										   res_18l_1718,
										   res_19l_1718,
										   res_20l_1718,
										   res_21l_1718,
										   res_22l_1718,
										   res_23l_1718,
										   res_24l_1718,
										   res_25l_1718,
										   res_26l_1718,
										   res_27l_1718,
										   res_28l_1718,
										   res_29l_1718,
										   res_30l_1718,
										   res_31l_1718,
										   res_32l_1718,
										   res_33l_1718,
										   res_34l_1718,
										   rp_34l_1718,
										   zero_1718  
										   })
										   );
										   
 Int_DivisorLvl_25b lvl35(
                                          // INPUTS //
                                          .N(ma_1718[13]),
                                          .D(mb_1718),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_34l_1718[23:0]),
                                          .rp(rp_35l),
                                          .cout(cout_35l)
                                          );
                                          assign res_35l = cout_35l[24];
                                         
 Int_DivisorLvl_25b lvl36(
                                          // INPUTS //
                                          .N(ma_1718[12]),
                                          .D(mb_1718),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_35l[23:0]),
                                          .rp(rp_36l),
                                          .cout(cout_36l)
                                          );
                                          assign res_36l = cout_36l[24];
                                          
 Seg_Reg#(.REG_SIZE(149))
										   seg_reg_18(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_1718,
										   mask_1718,
										   output_sign_1718,
										   biased_exponent_1718,
										   op_exception_1718,
										   inf_nan_exception_1718,
										   den_exception_1718,
										   ma_1718,
										   mb_1718,
										   res_1l_1718,
										   res_2l_1718,
										   res_3l_1718,
										   res_4l_1718,
										   res_5l_1718,
										   res_6l_1718,
										   res_7l_1718,
										   res_8l_1718,
										   res_9l_1718,
										   res_10l_1718	,
										   res_11l_1718,
										   res_12l_1718,
										   res_13l_1718,
										   res_14l_1718,
										   res_15l_1718,
										   res_16l_1718,
										   res_17l_1718,
										   res_18l_1718	,
										   res_19l_1718,
										   res_20l_1718,
										   res_21l_1718,
										   res_22l_1718,
										   res_23l_1718,
										   res_24l_1718,
										   res_25l_1718,
										   res_26l_1718,
										   res_27l_1718,
										   res_28l_1718,
										   res_29l_1718,
										   res_30l_1718,
										   res_31l_1718,
										   res_32l_1718,
										   res_33l_1718,
										   res_34l_1718,
										   res_35l,
										   res_36l,				   
										   rp_36l,
										   zero_1718                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_1819,
										   mask_1819,
										   output_sign_1819,
										   biased_exponent_1819,
										   op_exception_1819,
										   inf_nan_exception_1819,
										   den_exception_1819,
										   ma_1819,
										   mb_1819,
										   res_1l_1819,
										   res_2l_1819,
										   res_3l_1819,
										   res_4l_1819,
										   res_5l_1819,
										   res_6l_1819,
										   res_7l_1819,
										   res_8l_1819,
										   res_9l_1819,
										   res_10l_1819,
										   res_11l_1819,
										   res_12l_1819,
										   res_13l_1819,
										   res_14l_1819,
										   res_15l_1819,
										   res_16l_1819,
										   res_17l_1819,
										   res_18l_1819,
										   res_19l_1819,
										   res_20l_1819,
										   res_21l_1819,
										   res_22l_1819,
										   res_23l_1819,
										   res_24l_1819,
										   res_25l_1819,
										   res_26l_1819,
										   res_27l_1819,
										   res_28l_1819,
										   res_29l_1819,
										   res_30l_1819,
										   res_31l_1819,
										   res_32l_1819,
										   res_33l_1819,
										   res_34l_1819,
										   res_35l_1819,
										   res_36l_1819,
										   rp_36l_1819,
										   zero_1819  
										   })
										   );
										                                             										                                                                                                                                										                                         	                                          										                                             	                                          										                                            	                                          										                                            	                                          									                                            	                                         									                                            	                                          								                                            		                                          											                                                                                     										                                                                                       										                                            	                                         										                                          
  Int_DivisorLvl_25b lvl37(
                                          // INPUTS //
                                          .N(ma_1819[11]),
                                          .D(mb_1819),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_36l_1819[23:0]),
                                          .rp(rp_37l),
                                          .cout(cout_37l)
                                          );
                                          assign res_37l = cout_37l[24];
                                          
  Int_DivisorLvl_25b lvl38(
                                          // INPUTS //
                                          .N(ma_1819[10]),
                                          .D(mb_1819),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_37l[23:0]),
                                          .rp(rp_38l),
                                          .cout(cout_38l)
                                          );
                                          assign res_38l = cout_38l[24];
                                          
 Seg_Reg#(.REG_SIZE(151))
										   seg_reg_19(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_1819,
										   mask_1819,
										   output_sign_1819,
										   biased_exponent_1819,
										   op_exception_1819,
										   inf_nan_exception_1819,
										   den_exception_1819,
										   ma_1819,
										   mb_1819,
										   res_1l_1819,
										   res_2l_1819,
										   res_3l_1819,
										   res_4l_1819,
										   res_5l_1819,
										   res_6l_1819,
										   res_7l_1819,
										   res_8l_1819,
										   res_9l_1819,
										   res_10l_1819	,
										   res_11l_1819,
										   res_12l_1819,
										   res_13l_1819,
										   res_14l_1819,
										   res_15l_1819,
										   res_16l_1819,
										   res_17l_1819,
										   res_18l_1819	,
										   res_19l_1819,
										   res_20l_1819,
										   res_21l_1819,
										   res_22l_1819,
										   res_23l_1819,
										   res_24l_1819,
										   res_25l_1819,
										   res_26l_1819,
										   res_27l_1819,
										   res_28l_1819,
										   res_29l_1819,
										   res_30l_1819,
										   res_31l_1819,
										   res_32l_1819,
										   res_33l_1819,
										   res_34l_1819,
										   res_35l_1819,
										   res_36l_1819,
										   res_37l,
										   res_38l,				   
										   rp_38l,
										   zero_1819                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_1920,
										   mask_1920,
										   output_sign_1920,
										   biased_exponent_1920,
										   op_exception_1920,
										   inf_nan_exception_1920,
										   den_exception_1920,
										   ma_1920,
										   mb_1920,
										   res_1l_1920,
										   res_2l_1920,
										   res_3l_1920,
										   res_4l_1920,
										   res_5l_1920,
										   res_6l_1920,
										   res_7l_1920,
										   res_8l_1920,
										   res_9l_1920,
										   res_10l_1920,
										   res_11l_1920,
										   res_12l_1920,
										   res_13l_1920,
										   res_14l_1920,
										   res_15l_1920,
										   res_16l_1920,
										   res_17l_1920,
										   res_18l_1920,
										   res_19l_1920,
										   res_20l_1920,
										   res_21l_1920,
										   res_22l_1920,
										   res_23l_1920,
										   res_24l_1920,
										   res_25l_1920,
										   res_26l_1920,
										   res_27l_1920,
										   res_28l_1920,
										   res_29l_1920,
										   res_30l_1920,
										   res_31l_1920,
										   res_32l_1920,
										   res_33l_1920,
										   res_34l_1920,
										   res_35l_1920,
										   res_36l_1920,
										   res_37l_1920,
										   res_38l_1920,
										   rp_38l_1920,
										   zero_1920  
										   })
										   );
										   
  Int_DivisorLvl_25b lvl39(
                                          // INPUTS //
                                          .N(ma_1920[9]),
                                          .D(mb_1920),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_38l_1920[23:0]),
                                          .rp(rp_39l),
                                          .cout(cout_39l)
                                          );
                                          assign res_39l = cout_39l[24];
                                          
  Int_DivisorLvl_25b lvl40(
                                          // INPUTS //
                                          .N(ma_1920[8]),
                                          .D(mb_1920),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_39l[23:0]),
                                          .rp(rp_40l),
                                          .cout(cout_40l)
                                          );
                                          assign res_40l = cout_40l[24];
                                          
 Seg_Reg#(.REG_SIZE(153))
										   seg_reg_20(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_1920,
										   mask_1920,
										   output_sign_1920,
										   biased_exponent_1920,
										   op_exception_1920,
										   inf_nan_exception_1920,
										   den_exception_1920,
										   ma_1920,
										   mb_1920,
										   res_1l_1920,
										   res_2l_1920,
										   res_3l_1920,
										   res_4l_1920,
										   res_5l_1920,
										   res_6l_1920,
										   res_7l_1920,
										   res_8l_1920,
										   res_9l_1920,
										   res_10l_1920	,
										   res_11l_1920,
										   res_12l_1920,
										   res_13l_1920,
										   res_14l_1920,
										   res_15l_1920,
										   res_16l_1920,
										   res_17l_1920,
										   res_18l_1920	,
										   res_19l_1920,
										   res_20l_1920,
										   res_21l_1920,
										   res_22l_1920,
										   res_23l_1920,
										   res_24l_1920,
										   res_25l_1920,
										   res_26l_1920,
										   res_27l_1920,
										   res_28l_1920,
										   res_29l_1920,
										   res_30l_1920,
										   res_31l_1920,
										   res_32l_1920,
										   res_33l_1920,
										   res_34l_1920,
										   res_35l_1920,
										   res_36l_1920,
										   res_37l_1920,
										   res_38l_1920,
										   res_39l,
										   res_40l,				   
										   rp_40l,
										   zero_1920                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_2021,
										   mask_2021,
										   output_sign_2021,
										   biased_exponent_2021,
										   op_exception_2021,
										   inf_nan_exception_2021,
										   den_exception_2021,
										   ma_2021,
										   mb_2021,
										   res_1l_2021,
										   res_2l_2021,
										   res_3l_2021,
										   res_4l_2021,
										   res_5l_2021,
										   res_6l_2021,
										   res_7l_2021,
										   res_8l_2021,
										   res_9l_2021,
										   res_10l_2021,
										   res_11l_2021,
										   res_12l_2021,
										   res_13l_2021,
										   res_14l_2021,
										   res_15l_2021,
										   res_16l_2021,
										   res_17l_2021,
										   res_18l_2021,
										   res_19l_2021,
										   res_20l_2021,
										   res_21l_2021,
										   res_22l_2021,
										   res_23l_2021,
										   res_24l_2021,
										   res_25l_2021,
										   res_26l_2021,
										   res_27l_2021,
										   res_28l_2021,
										   res_29l_2021,
										   res_30l_2021,
										   res_31l_2021,
										   res_32l_2021,
										   res_33l_2021,
										   res_34l_2021,
										   res_35l_2021,
										   res_36l_2021,
										   res_37l_2021,
										   res_38l_2021,
										   res_39l_2021,
										   res_40l_2021,
										   rp_40l_2021,
										   zero_2021 
										   })
										   );
										   
  Int_DivisorLvl_25b lvl41(
                                          // INPUTS //
                                          .N(ma_2021[7]),
                                          .D(mb_2021),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_40l_2021[23:0]),
                                          .rp(rp_41l),
                                          .cout(cout_41l)
                                          );
                                          assign res_41l = cout_41l[24];
                                          
  Int_DivisorLvl_25b lvl42(
                                          // INPUTS //
                                          .N(ma_2021[6]),
                                          .D(mb_2021),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_41l[23:0]),
                                          .rp(rp_42l),
                                          .cout(cout_42l)
                                          );
                                          assign res_42l = cout_42l[24];
                                          
  Seg_Reg#(.REG_SIZE(155))
										   seg_reg_21(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_2021,
										   mask_2021,
										   output_sign_2021,
										   biased_exponent_2021,
										   op_exception_2021,
										   inf_nan_exception_2021,
										   den_exception_2021,
										   ma_2021,
										   mb_2021,
										   res_1l_2021,
										   res_2l_2021,
										   res_3l_2021,
										   res_4l_2021,
										   res_5l_2021,
										   res_6l_2021,
										   res_7l_2021,
										   res_8l_2021,
										   res_9l_2021,
										   res_10l_2021	,
										   res_11l_2021,
										   res_12l_2021,
										   res_13l_2021,
										   res_14l_2021,
										   res_15l_2021,
										   res_16l_2021,
										   res_17l_2021,
										   res_18l_2021	,
										   res_19l_2021,
										   res_20l_2021,
										   res_21l_2021,
										   res_22l_2021,
										   res_23l_2021,
										   res_24l_2021,
										   res_25l_2021,
										   res_26l_2021,
										   res_27l_2021,
										   res_28l_2021,
										   res_29l_2021,
										   res_30l_2021,
										   res_31l_2021,
										   res_32l_2021,
										   res_33l_2021,
										   res_34l_2021,
										   res_35l_2021,
										   res_36l_2021,
										   res_37l_2021,
										   res_38l_2021,
										   res_39l_2021,
										   res_40l_2021,
										   res_41l,
										   res_42l,				   
										   rp_42l,
										   zero_2021                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_2122,
										   mask_2122,
										   output_sign_2122,
										   biased_exponent_2122,
										   op_exception_2122,
										   inf_nan_exception_2122,
										   den_exception_2122,
										   ma_2122,
										   mb_2122,
										   res_1l_2122,
										   res_2l_2122,
										   res_3l_2122,
										   res_4l_2122,
										   res_5l_2122,
										   res_6l_2122,
										   res_7l_2122,
										   res_8l_2122,
										   res_9l_2122,
										   res_10l_2122,
										   res_11l_2122,
										   res_12l_2122,
										   res_13l_2122,
										   res_14l_2122,
										   res_15l_2122,
										   res_16l_2122,
										   res_17l_2122,
										   res_18l_2122,
										   res_19l_2122,
										   res_20l_2122,
										   res_21l_2122,
										   res_22l_2122,
										   res_23l_2122,
										   res_24l_2122,
										   res_25l_2122,
										   res_26l_2122,
										   res_27l_2122,
										   res_28l_2122,
										   res_29l_2122,
										   res_30l_2122,
										   res_31l_2122,
										   res_32l_2122,
										   res_33l_2122,
										   res_34l_2122,
										   res_35l_2122,
										   res_36l_2122,
										   res_37l_2122,
										   res_38l_2122,
										   res_39l_2122,
										   res_40l_2122,
										   res_41l_2122,
										   res_42l_2122,
										   rp_42l_2122,
										   zero_2122  
										   })
										   ); 
										   
  Int_DivisorLvl_25b lvl43(
                                          // INPUTS //
                                          .N(ma_2122[5]),
                                          .D(mb_2122),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_42l_2122[23:0]),
                                          .rp(rp_43l),
                                          .cout(cout_43l)
                                          );
                                          assign res_43l = cout_43l[24];		
  
  Int_DivisorLvl_25b lvl44(
                                          // INPUTS //
                                          .N(ma_2122[4]),
                                          .D(mb_2122),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_43l[23:0]),
                                          .rp(rp_44l),
                                          .cout(cout_44l)
                                          );
                                          assign res_44l = cout_44l[24];		                                        
                                          								                                                                                     										                                             	                                          										                                                                                                                                  	                                         			                                          										                                                                                                                                										                                         	                                          										                                             	                                          										                                            	                                          										                                            	                                          									                                            	                                         									                                            	                                          								                                            		                                          											                                                                                     										                                                                                       										                                            	                                         										                                          
   Seg_Reg#(.REG_SIZE(157))
										   seg_reg_22(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_2122,
										   mask_2122,
										   output_sign_2122,
										   biased_exponent_2122,
										   op_exception_2122,
										   inf_nan_exception_2122,
										   den_exception_2122,
										   ma_2122,
										   mb_2122,
										   res_1l_2122,
										   res_2l_2122,
										   res_3l_2122,
										   res_4l_2122,
										   res_5l_2122,
										   res_6l_2122,
										   res_7l_2122,
										   res_8l_2122,
										   res_9l_2122,
										   res_10l_2122	,
										   res_11l_2122,
										   res_12l_2122,
										   res_13l_2122,
										   res_14l_2122,
										   res_15l_2122,
										   res_16l_2122,
										   res_17l_2122,
										   res_18l_2122	,
										   res_19l_2122,
										   res_20l_2122,
										   res_21l_2122,
										   res_22l_2122,
										   res_23l_2122,
										   res_24l_2122,
										   res_25l_2122,
										   res_26l_2122,
										   res_27l_2122,
										   res_28l_2122,
										   res_29l_2122,
										   res_30l_2122,
										   res_31l_2122,
										   res_32l_2122,
										   res_33l_2122,
										   res_34l_2122,
										   res_35l_2122,
										   res_36l_2122,
										   res_37l_2122,
										   res_38l_2122,
										   res_39l_2122,
										   res_40l_2122,
										   res_41l_2122,
										   res_42l_2122,
										   res_43l,
										   res_44l,			   
										   rp_44l,
										   zero_2122                    
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_2223,
										   mask_2223,
										   output_sign_2223,
										   biased_exponent_2223,
										   op_exception_2223,
										   inf_nan_exception_2223,
										   den_exception_2223,
										   ma_2223,
										   mb_2223,
										   res_1l_2223,
										   res_2l_2223,
										   res_3l_2223,
										   res_4l_2223,
										   res_5l_2223,
										   res_6l_2223,
										   res_7l_2223,
										   res_8l_2223,
										   res_9l_2223,
										   res_10l_2223,
										   res_11l_2223,
										   res_12l_2223,
										   res_13l_2223,
										   res_14l_2223,
										   res_15l_2223,
										   res_16l_2223,
										   res_17l_2223,
										   res_18l_2223,
										   res_19l_2223,
										   res_20l_2223,
										   res_21l_2223,
										   res_22l_2223,
										   res_23l_2223,
										   res_24l_2223,
										   res_25l_2223,
										   res_26l_2223,
										   res_27l_2223,
										   res_28l_2223,
										   res_29l_2223,
										   res_30l_2223,
										   res_31l_2223,
										   res_32l_2223,
										   res_33l_2223,
										   res_34l_2223,
										   res_35l_2223,
										   res_36l_2223,
										   res_37l_2223,
										   res_38l_2223,
										   res_39l_2223,
										   res_40l_2223,
										   res_41l_2223,
										   res_42l_2223,
										   res_43l_2223,
										   res_44l_2223,
										   rp_44l_2223,
										   zero_2223  
										   })
										   ); 
										   
  Int_DivisorLvl_25b lvl45(
                                          // INPUTS //
                                          .N(ma_2223[3]),
                                          .D(mb_2223),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_44l_2223[23:0]),
                                          .rp(rp_45l),
                                          .cout(cout_45l)
                                          );
                                          assign res_45l = cout_45l[24];
                                          
										   
  Int_DivisorLvl_25b lvl46(
                                          // INPUTS //
                                          .N(ma_2223[2]),
                                          .D(mb_2223),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_45l[23:0]),
                                          .rp(rp_46l),
                                          .cout(cout_46l)
                                          );
                                          assign res_46l = cout_46l[24];
                                          
   Seg_Reg#(.REG_SIZE(159))
										   seg_reg_23(
										   // INPUTS //
										   .reset(reset),
										   .clk(clk),
										   .reg_in({valid_2223,
										   mask_2223,
										   output_sign_2223,
										   biased_exponent_2223,
										   op_exception_2223,
										   inf_nan_exception_2223,
										   den_exception_2223,
										   ma_2223,
										   mb_2223,
										   res_1l_2223,
										   res_2l_2223,
										   res_3l_2223,
										   res_4l_2223,
										   res_5l_2223,
										   res_6l_2223,
										   res_7l_2223,
										   res_8l_2223,
										   res_9l_2223,
										   res_10l_2223	,
										   res_11l_2223,
										   res_12l_2223,
										   res_13l_2223,
										   res_14l_2223,
										   res_15l_2223,
										   res_16l_2223,
										   res_17l_2223,
										   res_18l_2223	,
										   res_19l_2223,
										   res_20l_2223,
										   res_21l_2223,
										   res_22l_2223,
										   res_23l_2223,
										   res_24l_2223,
										   res_25l_2223,
										   res_26l_2223,
										   res_27l_2223,
										   res_28l_2223,
										   res_29l_2223,
										   res_30l_2223,
										   res_31l_2223,
										   res_32l_2223,
										   res_33l_2223,
										   res_34l_2223,
										   res_35l_2223,
										   res_36l_2223,
										   res_37l_2223,
										   res_38l_2223,
										   res_39l_2223,
										   res_40l_2223,
										   res_41l_2223,
										   res_42l_2223,
										   res_43l_2223,
										   res_44l_2223,
										   res_45l,
										   res_46l	,		   
										   rp_46l,
										   zero_2223                     
										   }),                       
										   // OUTPUTS // 
										   .reg_out_r({valid_2324,
										   mask_2324,
										   output_sign_2324,
										   biased_exponent_2324,
										   op_exception_2324,
										   inf_nan_exception_2324,
										   den_exception_2324,
										   ma_2324,
										   mb_2324,
										   res_1l_2324,
										   res_2l_2324,
										   res_3l_2324,
										   res_4l_2324,
										   res_5l_2324,
										   res_6l_2324,
										   res_7l_2324,
										   res_8l_2324,
										   res_9l_2324,
										   res_10l_2324,
										   res_11l_2324,
										   res_12l_2324,
										   res_13l_2324,
										   res_14l_2324,
										   res_15l_2324,
										   res_16l_2324,
										   res_17l_2324,
										   res_18l_2324,
										   res_19l_2324,
										   res_20l_2324,
										   res_21l_2324,
										   res_22l_2324,
										   res_23l_2324,
										   res_24l_2324,
										   res_25l_2324,
										   res_26l_2324,
										   res_27l_2324,
										   res_28l_2324,
										   res_29l_2324,
										   res_30l_2324,
										   res_31l_2324,
										   res_32l_2324,
										   res_33l_2324,
										   res_34l_2324,
										   res_35l_2324,
										   res_36l_2324,
										   res_37l_2324,
										   res_38l_2324,
										   res_39l_2324,
										   res_40l_2324,
										   res_41l_2324,
										   res_42l_2324,
										   res_43l_2324,
										   res_44l_2324,
										   res_45l_2324,
										   res_46l_2324,
										   rp_46l_2324,
										   zero_2324  
										   })
										   ); 
assign res_l = {	res_1l_2324,  
                    res_2l_2324,  
                    res_3l_2324,  
                    res_4l_2324,  
                    res_5l_2324,  
                    res_6l_2324,  
                    res_7l_2324,  
                    res_8l_2324,  
                    res_9l_2324,  
                    res_10l_2324, 
                    res_11l_2324, 
                    res_12l_2324, 
                    res_13l_2324, 
                    res_14l_2324, 
                    res_15l_2324, 
                    res_16l_2324, 
                    res_17l_2324, 
                    res_18l_2324, 
                    res_19l_2324, 
                    res_20l_2324, 
                    res_21l_2324, 
                    res_22l_2324, 
                    res_23l_2324, 
                    res_24l_2324, 
                    res_25l_2324, 
                    res_26l_2324, 
                    res_27l_2324, 
                    res_28l_2324, 
                    res_29l_2324, 
                    res_30l_2324, 
                    res_31l_2324, 
                    res_32l_2324, 
                    res_33l_2324, 
                    res_34l_2324, 
                    res_35l_2324, 
                    res_36l_2324, 
                    res_37l_2324, 
                    res_38l_2324, 
                    res_39l_2324, 
                    res_40l_2324, 
                    res_41l_2324, 
                    res_42l_2324, 
                    res_43l_2324, 
                    res_44l_2324, 
                    res_45l_2324, 
                    res_46l_2324};
                    									   
  Int_DivisorLvl_25b lvl47(
                                          // INPUTS //
                                          .N(ma_2324[1]),
                                          .D(mb_2324),
                                          .cin(1'b1),
                                          // OUTPUTS //
                                          .rpi(rp_46l_2324[23:0]),
                                          .rp(rp_47l),
                                          .cout(cout_47l)
                                          );
                                          assign res_47l = cout_47l[24];
										                                                              
  Int_DivisorLvl_25b lvl48(                                             
                                          // INPUTS //                  
                                          .N(ma_2324[0]),                    
                                          .D(mb_2324),                       
                                          .cin(1'b1),                   
                                          // OUTPUTS //                 
                                          .rpi(rp_47l[23:0]),           
                                          .rp(rp_48l),                  
                                          .cout(cout_48l)               
                                          );                            
                                          assign res_48l = cout_48l[24];
  
Div_Handler han              (
                                          // INPUTS //
                                          .valid(valid_2324),
                                          .mask(mask_2324),
                                          .output_sign(output_sign_2324),
                                          .biased_exponent(biased_exponent_2324),
                                          .res_l(res_l),
                                          .res_47l(res_47l),
                                          .res_48l(res_48l),
                                          .op_exception(op_exception_2324),
                                          .inf_nan_exception(inf_nan_exception_2324),
                                          .den_exception(den_exception_2324),
                                          .zero(zero_2324),
                                          // OUTPUTS //
                                          .result(final_result)
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

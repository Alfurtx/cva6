`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.12.2023 16:13:17
// Design Name: 
// Module Name: mul_aux
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

// Módulo de division de enteros implementado con un IPCore
// En lugar de usar un operador nativo de verilog se instancia
// un IPCore y se conectan sus entradas y salidas


module div_ipcore #(
    parameter DATA_WIDTH = 32, 
    parameter MVL = 32
) (
    input                       clk,      // Señal de reloj
    input                       rst,      // Señal de reset
    input                     start,      // Señal de inicio
    input                    op_div,      // Selector de operacion (0 division, 1 modulo)
    input [1:0]            cont_esc,      // Control escalar
    input [1+DATA_WIDTH-1:0] op_esc,      // Operador escalar
    input [MVL-1:0]            mask,      // Entrada de máscara
    input [bitwidth(MVL):0]     VLR,      // VLR
    input [32:0]               arg1,      // Operando 1
    input [32:0]               arg2,      // Operando 2
    output [33:0]               out,      // Salida de datos
    output                 reg busy       // Busy
);
    wire [DATA_WIDTH-1:0] value1;             // Valor operando 1
    wire [DATA_WIDTH-1:0] value2;             // Valor operando 2
    wire out_valid;                           // Bit valid del resultado
    wire [(DATA_WIDTH*2)-1:0] out_div;        // Resultado division:
                                              // 32 bits altos division
                                              // 32 bits resto
    wire [DATA_WIDTH-1:0] result;             // Resultado
    
    reg [bitwidth(MVL):0] vlr_reg;            // Registro para almacenar vlr
    reg [bitwidth(MVL):0] counter;            // Contador
    reg [1:0] cont_esc_reg;                   // Registro para almacenar el control escalar
    reg [1+DATA_WIDTH-1:0] op_esc_reg;        // Registro para almacenar el operador escalar
    reg [MVL-1:0] mask_reg;                   // Registro para almacenar la máscara
    reg op_div_reg;                           // Registro para alamcenar la operación seleccionada
    
    wire valid_arg1;                          // Bit valid del operando 1
    wire valid_arg2;                          // Bit valid del operando 2
    
    // Lógica para asignar los operandos
    // Si cont_esc_reg[1] = 0   =>	las entradas seran las salidas de los registros
    // Si cont_esc_reg[1] = 1   =>	hay que tener en  cuenta cont_esc_reg[0] para determinar las entradas
    // Si cont_esc_reg[0] = 0   =>	el operando escalar será el 1
    // Si cont_esc_reg[0] = 1   =>	el operando escalar será el 2
    
    assign valid_arg1 = (~cont_esc_reg[1]) ? arg1[DATA_WIDTH] :                       // Si no hay escalar -> valid_arg1 recibe el bit valid de la entrada arg1
                        (cont_esc_reg[0])  ? arg1[DATA_WIDTH] :                       // Si hay escalar y es el fuente 2 -> valid_arg1 recibe el bit de arg1 (NO SE DA NUNCA)
                        op_esc_reg[DATA_WIDTH];                                       // Si hay escalar y es el fuente 1 -> valid_arg1 recibe el bit del operando escalar
    
    assign valid_arg2 = (~cont_esc_reg[1]) ? arg2[DATA_WIDTH] :                       // Si no escalar -> valid_arg2 recibe el bit de la entrada arg2
                        (~cont_esc_reg[0]) ? arg2[DATA_WIDTH] :                       // Si el escalar es el fuente 1 -> valid_arg2 recibe el bit de arg2
                        op_esc_reg[DATA_WIDTH];                                       // Si el escalar es el fuente 2 -> valid_arg2 recibe el bit del operando escalar (NO SE DA NUNCA)
    
    assign value1 = 	(~cont_esc_reg[1]) ? arg1[DATA_WIDTH-1:0] :
    				    ( cont_esc_reg[0]) ? arg1[DATA_WIDTH-1:0] : op_esc_reg[DATA_WIDTH-1:0];
    assign value2 = 	(~cont_esc_reg[1]) ? arg2[DATA_WIDTH-1:0] :
						(~cont_esc_reg[0]) ? arg2[DATA_WIDTH-1:0] : op_esc_reg[DATA_WIDTH-1:0];
						
    assign result = (op_div_reg) ? out_div[DATA_WIDTH-1:0] : out_div[(DATA_WIDTH*2)-1:DATA_WIDTH];
    assign out = (out_valid & (vlr_reg > 0)) ? {1'b1, mask_reg[(counter-1'b1)], result} : {1'b0, 1'b0,{DATA_WIDTH{1'b0}}};
    
    // Instanciación del IPCore, se le pasan los operandos y bits de validez, y da el resultado y el bit de valid correspondiente
    
	div_gen_0 your_instance_name (
	  .aclk(clk),                            // Señal de reloj
	  .s_axis_divisor_tvalid(valid_arg1),    // Valid del divisor
	  .s_axis_divisor_tdata(value1),         // Divisor
	  .s_axis_dividend_tvalid(valid_arg2),   // Valid del dividendo
	  .s_axis_dividend_tdata(value2),        // Valid del dividendo
	  .m_axis_dout_tvalid(out_valid),        // Valid del resultado
	  .m_axis_dout_tdata(out_div)            // Salida del resultado:
	                                         // 32 bits altos resultado division
	                                         // 32 bits bajos resto de la division
	);
	
	// Bloque de control de las señales, contadores y registros
    // Señal de reset -> se reincia todo
    // Señal de start -> capturo vlr, inicio contador, capturo control escalar, capturo operando escalar,
    // capturo selección de operación, capturo máscara y activo busy
    // Mientras operador este busy y si salida del registro de desplazamiento es válida:
    // (registro de desplazamiento explicado en el siguiente bloque generate)
    // Si contador < vlr -> incrementar contador
    // Si contador == vlr -> reinciar contador y poner busy a 0
    
    always @(posedge clk) begin
		if (rst) begin
			vlr_reg <= 0;
			counter <= 0;
			cont_esc_reg <= 0;
			op_esc_reg <= 0;
			mask_reg <= 0;
			busy <= 0;
			op_div_reg <= 0;
		end else if (start) begin
			vlr_reg <= VLR;
			counter <= 1;
			cont_esc_reg <= cont_esc;
			op_esc_reg <= op_esc;
			mask_reg <= mask;
			op_div_reg <= op_div;
			busy <= 1;
		end else if (busy & out_valid) begin
			if (counter < vlr_reg) begin
				counter <= counter + 1;
			end else begin
				counter <= 0;
				busy <= 0;
			end
        end
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

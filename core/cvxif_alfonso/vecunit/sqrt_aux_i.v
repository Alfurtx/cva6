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


// FUNCIONA IGUAL QUE EL DIVISOR CON IPCORE, CON LA DIFERENCIA DE QUE
// AHORA NO TENEMOS DOS OPERANDOS, SOLO 1 (ya que es una raíz cuadrada)
// Y LA INSTANCIACIÓN DEL IP CORE CAMBIA AL SER OTRO MÓDULO

module sqrt_aux_i #(
    parameter DATA_WIDTH = 32, 
    parameter MVL = 32
) (
    input clk,
    input rst,
    input start,
    input [1:0] cont_esc,
    input [1+DATA_WIDTH-1:0] op_esc,
    input [MVL-1:0] mask,
    input [bitwidth(MVL):0] VLR,
    input [32:0] arg1,
    output [33:0] out,
    output reg busy
);
    wire [DATA_WIDTH-1:0] value1;
    wire [DATA_WIDTH-1:0] value2;
    wire in_valid;
    wire out_valid;
    wire [23:0] out_sqrt;
    wire [DATA_WIDTH-1:0] result;
    
    reg [bitwidth(MVL):0] vlr_reg;
    reg [bitwidth(MVL):0] counter;
    reg [1:0] cont_esc_reg;
    reg [1+DATA_WIDTH-1:0] op_esc_reg;
    reg [MVL-1:0] mask_reg;
    
    assign value1 = (~cont_esc_reg[1]) ? arg1[DATA_WIDTH-1:0] :
                    ( cont_esc_reg[0]) ? arg1[DATA_WIDTH-1:0] : op_esc_reg[DATA_WIDTH-1:0];
                    
    assign result = {{8{1'b0}}, out_sqrt};
    
    assign in_valid = (~cont_esc_reg[1]) ? arg1[DATA_WIDTH] :
                      ( cont_esc_reg[0]) ? arg1[DATA_WIDTH] : op_esc_reg[DATA_WIDTH];
    assign out = (out_valid & (vlr_reg > 0)) ? {out_valid, mask_reg[counter], result} : {out_valid, 1'b0,result};
    
    // Instanciación del IPCore, se le pasan los operandos y bits de validez, y da el resultado y el bit de valid correspondiente
    
    sqrt_aux sqrt_inst (
	  .aclk(clk),							// Señal de reloj
	  .s_axis_cartesian_tvalid(in_valid),   // Valid del operando
	  .s_axis_cartesian_tdata(value1),		// Valor del operando
	  .m_axis_dout_tvalid(out_valid),       // Valid del resultado
	  .m_axis_dout_tdata(out_sqrt)          // Valor del resultado
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
		end else if (start) begin
			vlr_reg <= VLR;
			counter <= 1;
			cont_esc_reg <= cont_esc;
			op_esc_reg <= op_esc;
			mask_reg <= mask;
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

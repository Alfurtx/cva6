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

//////////////////////////////////////////////////////////////////////////////////////
//   Alu aux: operador de suma de enteros implementado directamente con el símbolo  //
//   de suma. Tiene segmentación simulada                                           //
//////////////////////////////////////////////////////////////////////////////////////

`define DEBUG_ALU

module alu_aux #(
    parameter DATA_WIDTH = 32, 
    parameter MVL = 32, 
    parameter SEGMENTS = 4, 
    parameter ID = 0
) (
    input clk,                        // Señal de reloj
    input rst,                        // Señal de reset
    input start,                      // Señal de inicio
    input [1:0] cont_esc,             // Control escalar
                                      // esc[1] indica si la operacion usa un escalar (0 no / 1 si)
                                      // esc[0] obsoleto (se usaba para indicar qué fuente (1 o 2) era el escalar
                                      // Pero resulta que según la implementación del github el escalar siempre es el fuente 1
                                      // La lógica se ha hecho teniendo en cuenta que tanto fuente 1 como 2 podian ser escalar
                                      // Para apañarlo, desde el decodificador se deja SIEMPRE esc[0] a 0,
                                      // esto indica que el escalar será el fuente 1 (así no hace falta cambiar la implementacion de la logica)
    input [1+DATA_WIDTH-1:0] op_esc,  // Entrada del operando escalar
    input [MVL-1:0] mask,             // Entrada de la máscara
    input opcode,                     // Entrada de código de operacion: 0 -> suma, 1 -> resta
    input [bitwidth(MVL):0] VLR,      // Entrada del VLR
    input [32:0] arg1,                // Entrada del primer operando (bit valid + dato)
    input [32:0] arg2,                // Entrada del segundo operando (bit valid + dato)
    output [33:0] out,                // Salida del resultado (bit valid + bit máscara + dato)
    output reg busy                   // Salida para indicar operador ocupado
    );
    
    localparam valid_pos = DATA_WIDTH;
    
    wire valid_arg1;                  // Wire que alamcena el bit valid del operando 1
    wire valid_arg2;                  // Wire que alamcena el bit valid del operando 2
    wire [31:0] value1;               // Wire que alamcena el valor del operando 1
    wire [31:0] value2;               // Wire que alamcena el valor del operando 2
    wire [31:0] result;               // Wire que almacena el valor del resultado
    wire valid_result;                // Wire que almacena el bit valid del resultado
    
    
    reg [bitwidth(MVL):0] vlr_reg;				      // Registro para almacenar el vlr para la operacion
    reg [bitwidth(MVL):0] counter;			          // Contador
    reg [1:0] cont_esc_reg;							  // Registro para almacenar la configuracion escalar
    reg [1+DATA_WIDTH-1:0] op_esc_reg;                // Registro para almacenar el operador escalar

    reg [MVL-1:0] mask_reg;						      // Registro para almacenar la máscara
    reg opcode_reg;									  // Registro para almacenar la operacion a realizar
    
    reg [DATA_WIDTH:0] despl_reg[0:SEGMENTS-1];       // Registro de desplazamiento para simular la segmentación
    
    //	Lógica para asignar los operandos
    //	Si cont_esc_reg[1] = 0   =>	las entradas seran las salidas de los registros
    //	Si cont_esc_reg[1] = 1   =>	hay que tener en  cuenta cont_esc_reg[0] para determinar las entradas
    //	Si cont_esc_reg[0] = 0   =>	el operando escalar será el 1 (AHORA ESTE CASO SE DA SIEMPRE GRACIAS A LA DECODIFICACION)
    //	Si cont_esc_reg[0] = 1	 =>	el operando escalar será el 2 (AHORA ESTE CASO NO SE DA NUNCA GRACIAS A LA DECODIFICACION)
    
    assign valid_arg1 = (~cont_esc_reg[1]) ? arg1[DATA_WIDTH] :                       // Si no hay escalar -> valid_arg1 recibe el bit valid de la entrada arg1
                        ( cont_esc_reg[0]) ? arg1[DATA_WIDTH] :                       // Si hay escalar y es el fuente 2 -> valid_arg1 recibe el bit de arg1 (NO SE DA NUNCA)
                        op_esc_reg[DATA_WIDTH];                                       // Si hay escalar y es el fuente 1 -> valid_arg1 recibe el bit del operando escalar
    
    assign valid_arg2 = (~cont_esc_reg[1]) ? arg2[DATA_WIDTH] :                       // Si no escalar -> valid_arg2 recibe el bit de la entrada arg2
                        (~cont_esc_reg[0]) ? arg2[DATA_WIDTH] :                       // Si el escalar es el fuente 1 -> valid_arg2 recibe el bit de arg2
                        op_esc_reg[DATA_WIDTH];                                       // Si el escalar es el fuente 2 -> valid_arg2 recibe el bit del operando escalar (NO SE DA NUNCA)
    
    assign value1 =   (~cont_esc_reg[1])                    ? arg1[DATA_WIDTH-1:0] :  // Si no escalar -> value1 recibe valor de arg1
                      ( cont_esc_reg[1] & cont_esc_reg[0])  ? arg1[DATA_WIDTH-1:0] :  // Si el escalar es el fuente 2 -> value1 recibe valor de arg1 (NO SE DA NUNCA)
                      op_esc_reg[DATA_WIDTH-1:0];                                     // Si el escalar es el fuente 1 -> value1 recibe valor de op_esc_reg
    assign value2 =   (~cont_esc_reg[1])                    ? arg2[DATA_WIDTH-1:0] :  // Si no escalar -> value2 recibe valor de arg2
                      ( cont_esc_reg[1] & ~cont_esc_reg[0]) ? arg2[DATA_WIDTH-1:0] :  // Si el escalar es el fuente 1 -> value2 recibe valor de arg2
                      op_esc_reg[DATA_WIDTH-1:0];                                     // Si el escalar es el fuente 2 -> value2 recibe valor de op_esc_reg (NO SE DA NUNCA)
								
								
    // Si opcode = 0 suma, si = 1 resta
    // Este resultado será enviado hacia el registro de desplazamiento para simular segmentación
    assign result = (~opcode_reg) ? value1+value2 : value2 - value1;
    // Para el valid del resultado, usamos el and de los valids de los operandos
    assign valid_result =  valid_arg1 & valid_arg2;
    
    // Si los operandos son validos, la salida sera siempre: valid -- bit de máscara (el bit apuntado por el contador) -- resultado
    // la máscara será siempre 1 (si la operacion es sin máscara) o 1/0 si la operacion es con máscara
    assign out = (despl_reg[SEGMENTS-1][valid_pos] & (vlr_reg > 0)) ? {despl_reg[SEGMENTS-1][valid_pos],          // Bit de valid (salida del registro de desplazamiento)
                                                                        mask_reg[(counter-1'b1)],                 // Bit de máscara (tomado de la máscara capturada)
                                                                        despl_reg[SEGMENTS-1][valid_pos-1:0]} :   // Dato de 32 bits (salida del registro de desplazamiento)
                                                                        
                                                                       {despl_reg[SEGMENTS-1][valid_pos],         // Bit de valid (salida del registro de desplazamiento)
                                                                        1'b0,                                     // Cero
                                                                        despl_reg[SEGMENTS-1][valid_pos-1:0]};    // Dato de 32 bits (salida del registro de desplazamiento
    
    
    
    // Bloque de control de las señales, contadores y registros
    // Señal de reset -> se reincia todo
    // Señal de start -> capturo vlr, inicio contador, capturo control escalar, capturo operando escalar,
    // capturo máscara, capturo código de operación y activo busy
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
			opcode_reg <= 0;
			busy <= 0;
		end else if (start) begin
			vlr_reg <= VLR;
			counter <= 1;
			cont_esc_reg <= cont_esc;
			op_esc_reg <= op_esc;
			mask_reg <= mask;
			opcode_reg <= opcode;
			busy <= 1;
		end else if (busy & despl_reg[SEGMENTS-1][valid_pos]) begin
			//	Si estoy busy y el contador es menor que vlr, incremento contador
			if (counter < vlr_reg) begin
				counter <= counter + 1;
			end else begin
			//	Si estoy busy y el contador es igual que vlr, reinicio contador y pongo busy a 0
				counter <= 0;
				busy <= 0;
			end
        end
    end
    
    
    // Bloque generate para controlar el registro de desplazamiento
    // El resultado que se genera sobre el wire result y el bit de valid_result
    // se concatenan y se ponen en la posición 0 del registro. Ciclo a ciclo se van
    // desplazando a la siguiente posición hasta llegar a la última.
    // Esta última posición es la que se lee para generar la salida del operador
    
    generate
    	genvar seg;
    	for (seg = 0; seg < SEGMENTS; seg = seg + 1) begin: despl_gen
			always @(posedge clk) begin
				if (rst) begin
					despl_reg[seg] <= 0;
				end else if (busy) begin
					if(seg == 0) begin
						despl_reg[seg] <= {valid_result, result};
					end else begin
						despl_reg[seg] <= despl_reg[seg-1];
					end
				end
			end
		end
    endgenerate
        
        
    // synthesis translate_off
        
	`ifdef DEBUG_ALU
		reg[15:0] tics;
		always @(posedge clk) begin
			if (rst) begin
				tics <= 0;
			end else begin
				tics <= tics + 1;
			end
		end
		
		always@(posedge clk) begin
			if(start) begin
//				$display ("Start alu %1d with SEG = %1d in tic %d", ID, SEGMENTS, tics);
			end else if (despl_reg[SEGMENTS-1][DATA_WIDTH]) begin
//				$display ("Result alu %1d number %d = %2d in tic %d", ID, counter, despl_reg[SEGMENTS-1][DATA_WIDTH-1:0], tics);
			end
		end
	`endif
        
   // synthesis translate_on 
        
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
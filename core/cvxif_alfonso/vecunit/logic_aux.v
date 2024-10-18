`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.12.2023 16:13:17
// Design Name: 
// Module Name: logic_aux
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

`define DEBUG_LOG

module logic_aux #(
    parameter DATA_WIDTH = 32,
    parameter MVL = 16, 
    parameter NUM_LOGIC_OPS = bitwidth(20), 
    parameter SEGMENTS = 4, 
    parameter ID = 0
) (
    input clk,
    input rst,
    input start,
    input float,                            // Entrada para saber si es operacion float o normal (para las comparaciones)
    input [NUM_LOGIC_OPS-1:0] sel_logic_op, // Selector de operacion
    input [1:0] cont_esc,
    input [1+DATA_WIDTH-1:0] op_esc,
    input [MVL-1:0] mask,
    input [bitwidth(MVL):0] VLR,
    input [32:0] arg1,
    input [32:0] arg2,
    output [33:0] out,
    output reg busy
);
    
    wire valid_arg1;
    wire valid_arg2;
    wire [31:0] value1;
    wire [31:0] value2;
    wire valid_result;
    wire [31:0] result;
    wire [31:0] despl_reg_out;      // Wire para elegir qué saldrá del registro de desplazamiento
                                    // O el resultado que ha atravesado el registro, o el resultado de vid
    reg [bitwidth(MVL):0] vlr_reg;
    reg [bitwidth(MVL):0] counter;
    reg [bitwidth(MVL):0] counter_index;        // Contador para generar el índice, mientras la operación esté activa
                                                // Incrementará ciclo a ciclo, y su valor se enviará como resultado
                                                // Primer elemento -> índice = 0
                                                // Segundo elemento -> índice = 1
                                                // Tercer elemento -> índice = 2
                                                // ...
    reg [NUM_LOGIC_OPS-1:0] sel_logic_op_reg;
    reg [1:0] cont_esc_reg;
    reg [1+DATA_WIDTH-1:0] op_esc_reg;
    reg [MVL-1:0] mask_reg;
    reg float_reg;                              // Registro para saber si es una operacion float o normal
    
    reg [DATA_WIDTH-1:0] vcpop_acum;            // Registro para acumular el número de 1s en el registro leído
    reg [32:0] despl_reg[0:SEGMENTS-1];         // Registro de desplazamiento
    
    
    assign valid_arg1 = (~cont_esc_reg[1]) ? arg1[DATA_WIDTH] :
                        (cont_esc_reg[0])  ? arg1[DATA_WIDTH] : op_esc_reg[DATA_WIDTH];
    
    assign valid_arg2 = (~cont_esc_reg[1]) ? arg2[DATA_WIDTH] :
                        (~cont_esc_reg[0]) ? arg2[DATA_WIDTH] : op_esc_reg[DATA_WIDTH];
    
    assign value1 = 	(~cont_esc_reg[1])                   ? arg1[DATA_WIDTH-1:0] :
    					(cont_esc_reg[1] & cont_esc_reg[0])	 ? arg1[DATA_WIDTH-1:0] : op_esc_reg[DATA_WIDTH-1:0];
    assign value2 = 	(~cont_esc_reg[1])                   ? arg2[DATA_WIDTH-1:0] :
						(cont_esc_reg[1] & ~cont_esc_reg[0]) ? arg2[DATA_WIDTH-1:0] : op_esc_reg[DATA_WIDTH-1:0];
						
    wire signed [DATA_WIDTH-1:0] value2_s = value2;
						
	// En la mayoria de casos los resultados de las operaciones viajan a result, que se envia a la primera entrada del registro de desplazamiento
	// para simular la segmentación
	// Hay 2 casos especiales
	// En el caso de la operacion vid: 01111, el resultado se generará mediante el contador "counter_index"
	// En el caso de la operación vcpop: 10000. el resultado se genera en el bloque always de la linea 163
	// donde se va acumulando el número de 1s, y se da el resultado al final
    assign result = 	(sel_logic_op_reg == 5'b0000) 				? 	value2 == value1 	    :
                        (sel_logic_op_reg == 5'b0001) 				? 	value2 != value1		:
                        (~float_reg & sel_logic_op_reg == 5'b00010) ? 	value2 < value1		    :
                        (~float_reg & sel_logic_op_reg == 5'b00011) ? 	value2 << value1		:
                        (~float_reg & sel_logic_op_reg == 5'b00100) ? 	value2 >> value1		:
                        (~float_reg & sel_logic_op_reg == 5'b00101) ? 	value2_s >>> value1	    :
                        (~float_reg & sel_logic_op_reg == 5'b00110) ? 	value2 ^  value1		:
                        (~float_reg & sel_logic_op_reg == 5'b00111) ? 	value2 |  value1		:
                        (~float_reg & sel_logic_op_reg == 5'b01000) ? 	value2 &  value1		:
                        ( float_reg & sel_logic_op_reg == 5'b00010) ? 	(value2[31] > value1[31]) |	
                                                                        ((value2[31] == value1[31]) & (value2[30:23] < value1[30:23])) | 
                                                                        ((value2[31] == value1[31]) & (value2[30:23] == value1[30:23]) & (value2[22:0] != value1[22:0]))		: 
                        ( sel_logic_op_reg == 5'b01001)				?	{value2[DATA_WIDTH-1], value1[DATA_WIDTH-2:0]}		                                                    :
                        ( sel_logic_op_reg == 5'b01010)				?	{~value2[DATA_WIDTH-1], value1[DATA_WIDTH-2:0]}	                                                        :
                        ( sel_logic_op_reg == 5'b01011)				?	{value1[DATA_WIDTH-1] ^ value2[DATA_WIDTH-1], value1[DATA_WIDTH-2:0]}                                   : 
                        ( sel_logic_op_reg == 5'b01100)				?	value2[0] ^ value1[0]	:
                        ( sel_logic_op_reg == 5'b01101)				?	value2[0] | value1[0]	:
                        ( sel_logic_op_reg == 5'b01110)				? 	value2[0] & value1[0]	: 
                        ( sel_logic_op_reg == 5'b01111)             ?   0                       :
                        ( sel_logic_op_reg == 5'b10000)             ?   0 : 0;
	
	// Para el bit de validez, lo mismo, en las operaciones normales se hace & entre valid_arg1 y valid_arg2
	// En el caso de vid se pone directamente valid a 1 porque no hace falta recibir operandos para generar indices
	// En el caso de vcpop, solo hace falta el valid del arg2 (ya que tenemos un solo operando)
	assign valid_result = (busy & sel_logic_op_reg == 5'b01111) ? 1'b1     :
	                      (busy & sel_logic_op_reg == 5'b10000) ? arg2[32] :
	                      (busy & sel_logic_op_reg != 5'b10000 & sel_logic_op_reg != 5'b01111) ? valid_arg1 & valid_arg2 : 0;
	
	// Si es una operacion normal, la salida es la ultima posición del registro de desplazamiento
	// Si es una operacion vid, la salida es lo indicado por el contador de índice (que se usa para generar los índices de vid)
	assign despl_reg_out = (sel_logic_op_reg == 5'b01111)   ?  counter_index : despl_reg[SEGMENTS-1][DATA_WIDTH-1:0];
    
    // En la salida, si es una operación normal o vid, el resultado viene de despl_reg_out
    // Si es una operación vcpop, viene del registro donde hemos ido acumulando el número de 1s (vcpop_acum)
    assign out = (busy & despl_reg[SEGMENTS-1][DATA_WIDTH] & (sel_logic_op_reg != 5'b10000) & (vlr_reg > 0)) ?  {despl_reg[SEGMENTS-1][DATA_WIDTH], mask_reg[(counter-1'b1)], despl_reg_out} :
	             (busy & (counter > vlr_reg) & (sel_logic_op_reg == 5'b10000) & (vlr_reg > 0))              ?  {1'b1, 1'b1, vcpop_acum} : 0;
    
    
    // Bloque de control de las señales, contadores y registros
    // Señal de reset -> se reincia todo
    // Señal de start -> capturo vlr, inicio contador, inicio counter_index, capturo selector de operación, 
    // capturo control escalar, capturo operando escalar,, capturo máscara, capturo señal float y activo busy
    // Mientras el operador este busy y el dato saliente por el registro de desplazamiento sea valido o 
    // esté en una operación vcpop (en la que no se usa este registro):
    // Si contador < vlr -> incrementar contador
    //   Además, si estoy en una operación vid, incrementar el contador "counter_index" (para que pase a generar el siguiente índice)
    // Si contador == vlr -> reinciar registros y contadores y poner busy a 0
    
    always @(posedge clk) begin
		if (rst) begin
			vlr_reg <= 0;
			counter <= 0;
			counter_index <= 0;
			sel_logic_op_reg <= 0;
			cont_esc_reg <= 0;
			op_esc_reg <= 0;
			mask_reg <= 0;
			busy <= 0;
			float_reg <= 0;
		end else if (start) begin
			vlr_reg <= VLR;
			counter <= 1;
			counter_index <= 0;
			sel_logic_op_reg <= sel_logic_op;
			cont_esc_reg <= cont_esc;
			op_esc_reg <= op_esc;
			mask_reg <= mask;
			busy <= 1;
			float_reg <= float;
		end else if (busy & (despl_reg[SEGMENTS-1][DATA_WIDTH] | (sel_logic_op_reg == 5'b10000))) begin
			if (counter < vlr_reg | (sel_logic_op_reg == 5'b10000 & counter <= vlr_reg)) begin
				counter <= counter + 1;
				if (sel_logic_op_reg == 5'b01111) begin
			     counter_index <= counter_index + 1;
			    end
			end else begin
                counter <= 0;
                busy <= 0;
                sel_logic_op_reg <= 0;
			end
		end
	end
	
	// Bloque always para generar el resultado de la vcpop
	// Si reset, reinicio el contador vcpop
	// Si start, inicio a 0 el contador
	// Mientras el operador esté busy, si el dato entrante por el operando 2 es valid,
	// estoy en una operación vcpop, y el bit de máscara correspondiente al dato actual está a 1: sumo el bit de menor peso al registro
	// Si este bit es un 0, no incrementa, si es un 1 incrementa.
	// Esta operación genera un resultado escalar, no vectorial, por ello la máscara se ha manipulado de forma distinta
	// En lugar de generar un vector y asignar a cada elemento su bit de máscara
	// Se comprueba para cada elemento si su bit de máscara es 1 o 0, y se suma a la acumulación en base a ello
	
	always @(posedge clk) begin
	   if (rst) begin
	       vcpop_acum <= 0;
       end else if (start) begin
           vcpop_acum <= 0;
	   end else if (busy & valid_arg2 & (sel_logic_op_reg == 5'b10000) & mask_reg[counter]) begin
	       vcpop_acum <= vcpop_acum + value2[0];
	   end
	end
	
	
	// Bloque generate para el registro de desplazamiento que simula segmentación
	// Señal de reset -> se pone a 0
	// En cualquier otro caso, mientras el operador esté busy, 
	// el registro recibirá por la entrada el bit de validez del resultado y el valor concatenados
	// Este conjunto de datos atravesará todo el registro de desplazamiento y, al salir, se le añadirá su bit de máscara
	// como se hace en la linea 125
	
	generate
		genvar seg;
		for (seg = 0; seg < SEGMENTS; seg = seg + 1) begin: despl_gen
			always @(posedge clk) begin
				if (rst) begin
					despl_reg[seg] <= 0;
				end else if(busy) begin
					if(seg == 0) begin
						despl_reg[seg] <= {valid_result, result};
					end else begin
						despl_reg[seg] <= despl_reg[seg-1];
					end
				end else begin
				    despl_reg[seg] <= 0;
				end
			end
		end
	endgenerate
	
	
	// synthesis translate_off
	
	`ifdef DEBUG_LOG
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
//				$display ("Start logic %1d with SEG = %1d in tic %d", ID, SEGMENTS, tics);
			end else if (despl_reg[SEGMENTS-1][DATA_WIDTH]) begin
//				$display ("Result logic %1d number %d = %2d in tic %d", ID, counter, despl_reg[SEGMENTS-1][DATA_WIDTH-1:0], tics);
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
   integer temp;
   begin
   temp = value-1;
   for (log2=0; temp>0; log2=log2+1)
   temp = temp>>1;
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

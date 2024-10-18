`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.02.2024 10:40:07
// Design Name: 
// Module Name: unit_and_mem
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


module unit_and_mem #(
		parameter NUM_REGS = 32,
		parameter NUM_ESC_REGS = 32,
        parameter NUM_WRITE_PORTS = 2,
        parameter NUM_READ_PORTS = 2, 
        parameter DATA_WIDTH = 32,
        parameter VALID = 1,
        parameter MASK = 1,
        parameter WIDTH = DATA_WIDTH + VALID, 
        parameter MVL = 32, 
        parameter MEM_DEPTH = 10,
        parameter MEM_READ_PORTS = 2,
        parameter MAX_STRIDE = 16,
        parameter NUM_ALUS = 2,
        parameter NUM_MULS = 2,
        parameter NUM_DIVS = 2,
        parameter NUM_SQRTS = 2,
        parameter NUM_LOGICS = 2,
        parameter NUM_LOGIC_OPS = bitwidth(17),
        parameter NUM_F_ALUS = 2,
        parameter NUM_F_MULS = 2,
        parameter NUM_F_DIVS = 2,
        parameter NUM_F_SQRTS = 2,
        parameter NUM_F_ADDMULS = 2,
        parameter SIZE_QUEUE = 16	
	) (
		input clk,														//  Entrada de reloj
		input rst,
		input valid, 													//  Añadido asumiendo que la unidad de decodificacion emitirá un valid (a 0 cuando se detiene la decodificacion)
		input setvl,
		input add,														//  Indica que la instruccion es una suma
		input sub,														//  Indica que la instruccion es una resta
		input mul,														//  Indica que la instruccion es una multiplicacion
		input div, 														// 	Indica que la instruccion es una division
		input rem,
		input sqrt,
		input addmul,
		
		input peq,
		input pne,
		input plt,
		
		input sll,
		input srl,
		input sra,
		
		input log_xor,
		input log_or,
		input log_and,
		
		input sgnj,
		input sgnjn,
		input sgnjx,
		
		input pxor,
		input por,
		input pand,
		
		input vid,
		input vcpop,
		
		input float,		
		input [1:0] esc,												//  Control escalar: esc[1] -> 0 operacion sin operador escalar / 1 operacion usado un operador escalar
																		//	esc[0] -> 0 el operador escalar será el src1 / 1 el operador escalar será el src2
		input masked_op,												//  Control de mascara -> 0: operacion sin mascara 1: operacion con mascara
		input load,														//  Indica que la instruccion es una load
		input iload,														//	Indica que la instruccion es una indexed load
		input store,														//  Indica que la instruccion es una store
		input istore,														//	Indica que la instruccion es una indexed store
		input [bitwidth(NUM_REGS)-1:0] src1,				//  Indica el registro fuente 1
		input [bitwidth(NUM_REGS)-1:0] src2,				//  Indica el registro fuente 2
		input [bitwidth(NUM_ESC_REGS)-1:0] src_esc,						//  Indica el fuente escalar, si la operacion es escalar
		input [bitwidth(NUM_REGS)-1:0] dst,				//  Indica el registro destino
		input [bitwidth(NUM_ESC_REGS)-1:0] dst_esc,
		input [MEM_DEPTH-1:0] addr,							//  Indica la dirección base en la que leer/escribir
		input [bitwidth(MAX_STRIDE)-1:0] stride,			//  Indica el stride a aplicar para incrementar la direccion de lectura/escritura
		//input [bitwidth(MVL)-1:0] vector_length_reg,	//  Indica el numero de elementos de vector con los que se va a operar (VLR)
		output full,														//  Indica a la unidad de control que hay un stall y la codificación se debe detener
		output empty,
		output [DATA_WIDTH-1:0] data_read_o,
		output [DATA_WIDTH-1:0] data_write_o
    );
    
    
    
    wire [(DATA_WIDTH*MEM_READ_PORTS)-1:0] data_read;
    wire [WIDTH-1:0] data_write;
    wire [(MEM_DEPTH*MEM_READ_PORTS)-1:0] addr_read;
    wire [MEM_DEPTH-1:0] addr_write;
    wire write_busy;
    
    assign data_read_o = data_read;
    assign data_write_o = data_write;
    
    top_path_plus_control #(
            .NUM_REGS           ( NUM_REGS          ),
            .NUM_ESC_REGS       ( NUM_ESC_REGS      ),
            .NUM_WRITE_PORTS    ( NUM_WRITE_PORTS   ),
            .NUM_READ_PORTS     ( NUM_READ_PORTS    ),
            .DATA_WIDTH         ( DATA_WIDTH        ),
            .VALID              ( VALID             ),
            .MASK               ( MASK              ),
            .WIDTH              ( WIDTH             ),
            .MVL                ( MVL               ),
            .ADDRESS_WIDTH      ( MEM_DEPTH         ),
            .MEM_READ_PORTS     ( MEM_READ_PORTS    ),
            .MAX_STRIDE         ( MAX_STRIDE        ),
            .NUM_ALUS           ( NUM_ALUS          ),
            .NUM_MULS           ( NUM_MULS          ),
            .NUM_DIVS           ( NUM_DIVS          ),
            .NUM_SQRTS          ( NUM_SQRTS         ),
            .NUM_LOGICS         ( NUM_LOGICS        ),
            .NUM_LOGIC_OPS      ( NUM_LOGIC_OPS     ),
            .NUM_F_ALUS         ( NUM_F_ALUS        ),
            .NUM_F_MULS         ( NUM_F_MULS        ),
            .NUM_F_DIVS         ( NUM_F_DIVS        ),
            .NUM_F_SQRTS        ( NUM_F_SQRTS       ),
            .NUM_F_ADDMULS      ( NUM_F_ADDMULS     ),
            .SIZE_QUEUE         ( SIZE_QUEUE        )
        ) top (
            .clk                ( clk           ),
            .rst                ( rst           ),
            .valid              ( valid         ),
            .setvl              ( setvl         ),
            .add                ( add           ),
            .sub                ( sub           ),
            .mul                ( mul           ),
            .div                ( div           ),
            .rem                ( rem           ),
            .sqrt               ( sqrt          ),
            .addmul             ( addmul        ),
            .peq                ( peq           ),
			.pne                ( pne           ),
			.plt                ( plt           ),
			
			.sll                ( sll           ),
			.srl                ( srl           ),
			.sra                ( sra           ),
			
			.log_xor            ( log_xor       ),
			.log_or             ( log_or        ),
			.log_and            ( log_and       ),
			
			.sgnj               ( sgnj          ),
			.sgnjn              ( sgnjn         ),
			.sgnjx              ( sgnjx         ),
			
			.pxor               ( pxor          ),
			.por                ( por           ),
			.pand               ( pand          ),
			
			.vid                ( vid           ),
			.vcpop              ( vcpop         ),
			
			.float              ( float         ),
            .esc                ( esc           ),
            .masked_op          ( masked_op     ),
            .load               ( load          ),
            .iload              ( iload         ),
            .store              ( store         ),
            .istore             ( istore        ),
            .src1               ( src1          ),
            .src2               ( src2          ),
            .src_esc            ( src_esc       ),
            .dst                ( dst           ),
            .dst_esc            ( dst_esc       ),
            .addr               ( addr          ),
            .stride             ( stride        ),
            .full               ( full          ),
            .empty              ( empty         ),
            
            .mem_data_read_in   ( data_read     ),
            .mem_data_write_out ( data_write    ),
            .addr_read          ( addr_read     ),
            .addr_write         ( addr_write    ),
            .mem_w_busy         ( write_busy    )
            //.out_prueba ( out_prueba )
        );
    
    
    
    
    bram #(
        	.WIDTH ( DATA_WIDTH ),
        	.DEPTH ( MEM_DEPTH )
    	) memory (
    		.clk ( clk ),
    		.rst ( rst ),
    		.addr_read ( addr_read ),
    		.addr_write ( addr_write ),
    		.data ( data_write[DATA_WIDTH-1:0] ),
    		.w_en ( write_busy ),
    		.rd_o ( data_read )
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

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

// Módulo para comunicar top_path_plus_control, decodificador de instrucciones y memoria

module unit_dec_mem #(
      parameter NUM_REGS = 32,                    // Registros vectoriales
      parameter NUM_ESC_REGS = 32,                // Registros escalares
      parameter NUM_WRITE_PORTS = 2,              // Puertos de escritura en los registros vectoriales
      parameter NUM_READ_PORTS = 2,               // Puertos de lectura en los registros vectoriales
      parameter DATA_WIDTH = 32,                  // Anchura de dato
      parameter VALID = 1,                        // Anchura bit valid
      parameter MASK = 1,                         // Anchura bit máscara
      parameter WIDTH = DATA_WIDTH + VALID,       // Anchura dato + bit valid
      parameter MVL = 32,                         // Maximum Vector Length
      parameter MEM_DEPTH = 10,                   // Tamaño direccion de memoria, tamaño memoria = 2^MEM_DEPTH
      parameter MEM_READ_PORTS = 2,               // Puertos de lectura de memoria
      parameter MAX_STRIDE = 16,                  // Stride maximo
      parameter NUM_ALUS = 2,                     // Numero de alus
      parameter NUM_MULS = 2,                     // Numero de multiplicadores
      parameter NUM_DIVS = 2,                     // Numero de divisores
      parameter NUM_SQRTS = 2,                    // Numero de operadores de raiz cuadrada
      parameter NUM_LOGICS = 2,                   // Numero de operadores multifuncion
      parameter NUM_LOGIC_OPS = bitwidth(17),     // Numero de operaciones en el operador multifuncion
      parameter NUM_F_ALUS = 2,                   // Numero de alus float
      parameter NUM_F_MULS = 2,                   // Numero de multiplicadores float
      parameter NUM_F_DIVS = 2,                   // Numero de divisores float
      parameter NUM_F_SQRTS = 2,                  // Numero de operadores de raíz cuadrada float
      parameter NUM_F_ADDMULS = 2,                // NO SE USA
      parameter SIZE_QUEUE = 16	                  // Tamaño de la cola FIFO
	) (
      input                                clk,   // Señal de reloj
      input                                rst,   // Señal de reset
      input                              valid,   // Añadido asumiendo que la unidad de decodificacion emitirá un valid (a 0 cuando se detiene la decodificacion)
      input  [31:0]                      instr,   // Instruccion codificada
      output                              full,   // La unidad vectorial está en parada y la cola FIFO está llena
      output                             empty,   // Esta salida no tiene uso
      output [DATA_WIDTH+MASK-1:0] data_read_o,   // Esta salida no tiene uso (estaba puesta para poder hacer sintesis sin que se eliminara la logica interna)
      output [DATA_WIDTH-1:0]     data_write_o    // Esta salida no tiene uso (estaba puesta para poder hacer sintesis sin que se eliminara la logica interna)
    );
    
    
    
    wire [(DATA_WIDTH*MEM_READ_PORTS)-1:0] data_read;   // Datos leidos de memoria                      top_path_plus_control -> Memoria
    wire [WIDTH+MASK-1:0]                 data_write;   // Datos a escribir en memoria                  Memoria               -> top_path_plus_control
    wire [(MEM_DEPTH*MEM_READ_PORTS)-1:0]  addr_read;   // Direccion/es de lectura de memoria           top_path_plus_control -> Memoria
    wire [MEM_DEPTH-1:0]                  addr_write;   // Direccion de escritura de memoria            top_path_plus_control -> Memoria
    wire                                  write_busy;   // Puerto de escritura de memoria ocupado       Memoria               -> top_path_plus_control
    
    
    // Salidas del decodificador que viajan al top_path_plus_control                                    Decodificador         -> top_path_plus_control
    wire valid_o;
    wire setvl;
    wire add;
    wire [1:0] esc;
    wire sub;
    wire mul;
    wire div;
    wire rem;
    wire sqrt;
    wire addmul;
    wire peq;
    wire pne;
    wire plt;
    wire sll;
    wire srl;
    wire sra;
    wire log_xor;
    wire log_or;
    wire log_and;
    wire sgnj;
    wire sgnjn;
    wire sgnjx;
    wire pxor;
    wire por;
    wire pand;
    wire vid;
    wire vcpop;
    wire float;
    wire masked_op;
    wire load;
    wire iload;
    wire store;
    wire istore;
    wire [bitwidth(NUM_REGS)-1:0]         src1;
    wire [bitwidth(NUM_REGS)-1:0]         src2;
    wire [bitwidth(NUM_ESC_REGS)-1:0] src1_esc;
    wire [bitwidth(NUM_ESC_REGS)-1:0] src2_esc;
    wire [bitwidth(NUM_REGS)-1:0]          dst;
    wire [bitwidth(NUM_ESC_REGS)-1:0]  dst_esc;
    
    assign data_read_o = data_read;
    assign data_write_o = data_write;
    
    
    vect_instr_decoder #(
      .NUM_REGS     ( NUM_REGS     ),
      .NUM_ESC_REGS ( NUM_ESC_REGS ),
      .DATA_WIDTH   ( DATA_WIDTH   ),
      .MVL          ( MVL          )
    ) decodificador (
      .instr        ( instr        ),
      .valid_i      ( valid        ),
      .valid_o      ( valid_o      ),
      .setvl        ( setvl        ),
      .add          ( add          ),
      .sub          ( sub          ),
      .mul          ( mul          ),
      .div          ( div          ),
      .rem          ( rem          ),
      .sqrt         ( sqrt         ),
      .addmul       ( addmul       ),
      .peq          ( peq          ),
      .pne          ( pne          ),
      .plt          ( plt          ),
      .sll          ( sll          ),
      .srl          ( srl          ),
      .sra          ( sra          ),
      .log_xor      ( log_xor      ),
      .log_or       ( log_or       ),
      .log_and      ( log_and      ),
      .sgnj         ( sgnj         ),
      .sgnjn        ( sgnjn        ),
      .sgnjx        ( sgnjx        ),
      .pxor         ( pxor         ),
      .por          ( por          ),
      .pand         ( pand         ),
      .vid          ( vid          ),
      .vcpop        ( vcpop        ),
      .strided      ( strided      ),
      .float        ( float        ),
      .esc          ( esc          ),
      .masked_op    ( masked_op    ),
      .load         ( load         ),
      .iload        ( iload        ),
      .store        ( store        ),
      .istore       ( istore       ),
      .src1         ( src1         ),
      .src2         ( src2         ),
      .src1_esc     ( src1_esc     ),
      .src2_esc     ( src2_esc     ),
      .dst          ( dst          ),
      .dst_esc      ( dst_esc      )
    );
    
    
    
    
    
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
      .valid              ( valid_o       ),
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
	  
	  .strided            ( strided       ),
	  .float              ( float         ),
      .esc                ( esc           ),
      .masked_op          ( masked_op     ),
      .load               ( load          ),
      .iload              ( iload         ),
      .store              ( store         ),
      .istore             ( istore        ),
      .src1               ( src1          ),
      .src2               ( src2          ),
      .src1_esc           ( src1_esc       ),
      .src2_esc           ( src2_esc       ),
      .dst                ( dst           ),
      .dst_esc            ( dst_esc       ),
      .full               ( full          ),
      .empty              ( empty         ),
      .mem_data_read_in   ( data_read     ),
      .mem_data_write_out ( data_write    ),
      .addr_read          ( addr_read     ),
      .addr_write         ( addr_write    ),
      .mem_w_busy         ( write_busy    )
    );
    
    
    
    
    bram #(
      .WIDTH              ( DATA_WIDTH                                                               ),
      .DEPTH              ( MEM_DEPTH                                                                )
    ) memory (
      .clk                ( clk                                                                      ),
      .rst                ( rst                                                                      ),
      .addr_read          ( addr_read                                                                ),
      .addr_write         ( addr_write                                                               ),
      .data               ( data_write[DATA_WIDTH-1:0]                                               ),
      .w_en               ( write_busy & data_write[DATA_WIDTH] & data_write[DATA_WIDTH+VALID+MASK-1]),
      .rd_o               ( data_read                                                                )
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
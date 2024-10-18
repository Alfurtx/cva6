`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 31.10.2023 16:59:08
// Design Name: 
// Module Name: control_unit
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

module control_unit_dchinue #(
    parameter NUM_REGS        = 32,                        
    parameter NUM_ESC_REGS    = 32,                    
    parameter NUM_WRITE_PORTS = 2,                  
    parameter NUM_READ_PORTS  = 2, 
    parameter DATA_WIDTH      = 32,
    parameter VALID           = 1,
    parameter MASK            = 1,
    parameter WIDTH           = DATA_WIDTH + VALID, 
    parameter MVL             = 32, 
    parameter ADDRESS_WIDTH   = 10,
    parameter MEM_READ_PORTS  = 2,
    parameter MAX_STRIDE      = 16, 
    parameter NUM_ALUS        = 2,
    parameter NUM_MULS        = 2,
    parameter NUM_DIVS        = 2,
    parameter NUM_SQRTS       = 2,
    parameter NUM_LOGICS      = 2,
    parameter NUM_LOGIC_OPS   = bitwidth(14),
    parameter NUM_F_ALUS      = 2,
    parameter NUM_F_MULS      = 2,
    parameter NUM_F_DIVS      = 2,
    parameter NUM_F_SQRTS     = 2,
    parameter NUM_F_ADDMULS   = 2
) (
        // Puertos Unidad Control
    input                                            clk,                   // Señal de reloj
    input                                            rst,                   // Señal de reset
    
    // Señal para indicar que operación hace la instrucción actual
    input                                            setvl,
    input                                            add,
    input                                            sub,
    input                                            mul,
    input                                            div,
    input                                            rem,
    input                                            sqrt,
    input                                            addmul,
    input                                            peq,
    input                                            pne,
    input                                            plt,
    input                                            sll,
    input                                            srl,
    input                                            sra,
    input                                            log_xor,
    input                                            log_or,
    input                                            log_and,
    input                                            sgnj,
    input                                            sgnjn,
    input                                            sgnjx,
    input                                            pxor,
    input                                            por,
    input                                            pand,
    input                                            vid,
    input                                            vcpop,
    
    // Señales de información de la instruccion
    input                                            strided,               // Acceso a memoria regular secuencial = 0, regular no secuencial = 1
    input                                            float,                 // Operacion float o de enteros
    
    input [1:0]                                      esc,                   // Entrada para el control escalar
                                                                            // esc[1] indica si la operacion usa un escalar (0 no / 1 si)
                                                                            // esc[0] obsoleto (se usaba para indicar qué fuente (1 o 2) era el escalar
                                                                            // Pero resulta que según la implementación del github el escalar siempre es el fuente 1
                                                                            // La lógica se ha hecho teniendo en cuenta que tanto fuente 1 como 2 podian ser escalar
                                                                            // Para apañarlo, desde el decodificador se deja SIEMPRE esc[0] a 0,
                                                                            // esto indica que el escalar será el fuente 1 (así no hace falta cambiar la implementacion de la logica)
    input                                            masked_op,             // Operacion a realizar es enmascarada (0 no / 1 si)
    input                                            load,                  // Indica si la instruccion es una load
    input                                            iload,                 // Indica si es una load indexada (acceso no regular)
    input                                            store,                 // Indica si la instruccion es una store
    input                                            istore,                // Indica si es una store indexada (acceso no regular)
    input [bitwidth(NUM_REGS)-1:0]                   src1,                  // Registro vectorial fuente 1
    input [bitwidth(NUM_REGS)-1:0]                   src2,                  // Registro vectorial fuente 2
    input [bitwidth(NUM_ESC_REGS)-1:0]               src1_esc,              // Registro escalar fuente 1 si la operacion es escalar
    input [bitwidth(NUM_ESC_REGS)-1:0]               src2_esc,              // Registro escalar fuente 1 si la operacion es escalar (obsoleto)
    input [bitwidth(NUM_REGS)-1:0]                   dst,                   // Registro vectorial destino
    input [bitwidth(NUM_ESC_REGS)-1:0]               dst_esc,               // Registro escalar destino
    
    // Puertos busys Unidad Vectorial 
    input mem_w_busy,                                                       // Puerto de escritura de memoria ocupado
    input [MEM_READ_PORTS-1:0] mem_r_busy,                                  // Puerto/s de lectura de memoria ocupado/s
    input [NUM_WRITE_PORTS*NUM_REGS-1:0]             bank_w_busy,           // Bus que contiene los busys de escritura de todos los puertos de todos los registros 
                                                                            // (agrupados por registro)
                                                                            // [...busy_reg1_puerto1, busy_reg1_puerto0, busy_reg0_puerto1, busy_reg0_puerto0] 
                                                                            // (Todas las veces que diga que algo está agrupado por registro me refiero a esto de arriba
                                                                            // es decir, como en este caso, todos los puertos de un registro, luego los del siguiente, etc.) 
    input [NUM_READ_PORTS*NUM_REGS-1:0]              bank_r_busy,           // Bus que contiene los busys de lectura de todos los puertos de todos los registros 
                                                                            // (agrupados por registro)
    input                                            esc_w_busy,            // Indica hay un registro escalar preparado para escribir
    input [bitwidth(NUM_ESC_REGS)-1:0]               esc_reg_busy,          // Indica qué registro escalar está preparado para escribir
    input [NUM_ALUS-1:0]                             alu_busy,              // Bus que agrupa los busys de todas las alus en orden
    input [NUM_MULS-1:0]                             mul_busy,              // Bus que agrupa los busys de todos los multiplicadores
    input [NUM_DIVS-1:0]                             div_busy,				// Bus que agrupa los busys de todos los divisores
    input [NUM_SQRTS-1:0]                            sqrt_busy,             // Bus que agrupa los busys de todos los operadores sqrt  
    input [NUM_LOGICS-1:0]                           logic_busy,            // Bus que agrupa los busys de todos los operadores multipurpose
    input [NUM_F_ALUS-1:0]                           alu_f_busy,            // Bus que agrupa los busys de todos las alus float
    input [NUM_F_MULS-1:0]                           mul_f_busy,            // Bus que agrupa los busys de todos los multiplicadores float  
    input [NUM_F_DIVS-1:0]                           div_f_busy,            // Bus que agrupa los busys de todos los divisores float
    input [NUM_F_ADDMULS-1:0]                        addmul_f_busy,         // NO IMPLEMENTADO
    input [NUM_F_SQRTS-1:0]                          sqrt_f_busy,           // Bus que agrupa los busys de todos los operadores sqrt float
    input [NUM_REGS-1:0]                             first_elem,            // Entrada que me indica si el elemento 1 de cada registro está disponible (1 bit por registro)
    input [VALID+MASK-1:0]                           mask_copy_i,           // Copia de la máscara escrita sobre v0, llegan 2 bits: validez y bit a copiar
    input [DATA_WIDTH+VALID-1:0]                     esc_data_i_a,          // Dato leido del escalar fuente 1 (viene del banco de registros escalares)
    input [DATA_WIDTH+VALID-1:0]                     esc_data_i_b,          // Dato leido del escalar fuente 2 (viene del banco de registros escalares)
    input [DATA_WIDTH+MASK+VALID-1:0]                esc_data_result_i,     // Resultado escalar generado (viene del datapath)
    // Puertos señales hacia Unidad Vectorial
    output [bitwidth(MVL):0]                         VLR,                   // Salida para enviar el VLR
    output                                           float_signal,          // Salida para indicar operacion float
    // Mem/Load/Store
    output                                           mem_w_signal,          // Señal de escritura a memoria
    output [MEM_READ_PORTS-1:0]                      mem_r_signal,          // Señal de lectura a memoria (1 bit por puerto)
    output [ADDRESS_WIDTH-1:0]                       addr_signal,			// Salida de la direccion base de acceso a memoria
    output [bitwidth(MAX_STRIDE)-1:0]                stride_out,            // Salida para enviar a unidad load/store el stride a usar
    output                                           indexed_signal,        // Señal para indicar a unidad load/store acceso no regular
    
    // Para recibir índices en la unidad load/store se lee de registros vectoriales
    // Hay un multiplexor en cada puerto para poder elegir (en caso de que se haga un acceso con índices) de qué registro vectorial se leen los índices
    // Estas son las señales de seleccion de esos multiplexores
    output [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0]   indexed_st_sel,        // Señal de selección del multiplexor para elegir índice en escritura de memoria (agrupados por puertos)
    output [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0]   indexed_ld_sel,        // Señal de selección del multiplexor para elegir índice en lectura de memoria (agrupados por puertos)
    
    // Registros vectoriales
    output [NUM_WRITE_PORTS*NUM_REGS-1:0]            bank_w_signal,         // Todas las señales de escritura de los registros vectoriales, agrupadas por registro
    output [NUM_READ_PORTS*NUM_REGS-1:0]             bank_r_signal,         // Todas las señales de lectura de los registros vectoriales, agrupadas por registro
    output [NUM_WRITE_PORTS*NUM_REGS-1:0]            masked_vid_signal,     // Todas las señales de escritura vid de los registros vectoriales, agrupadas por registro
    // Registros escalares
    output                                           esc_r_en_a,            // Señal de lectura del registro escalar fuente 1
    output                                           esc_r_en_b,            // Señal de lectura del registro escalar fuente 2
    output                                           esc_w_en,              // Señal de escritura del registro escalar fuente
    output [bitwidth(NUM_ESC_REGS)-1:0]              esc_w_addr,            // Señal de qué registro escalar destino escribir
    output [bitwidth(NUM_ESC_REGS)-1:0]              esc_ra_addr,           // Señal de qué registro escalar fuente 1 leer
    output [bitwidth(NUM_ESC_REGS)-1:0]              esc_rb_addr,           // Señal de qué registro escalar fuente 2 leer
    output [VALID+DATA_WIDTH-1:0]                    esc_data_o,            // Salida de datos leídos del registro escalar fuente 1
    output [DATA_WIDTH+MASK+VALID-1:0]               esc_data_result_o,     // Salida del resultado escalar generado (se envía havia el banco de registros escalares)
    // ALU 
    output                                           op,                    // Salida para indicar a la alu la operacion a realizar (suma o resta)
    output [NUM_ALUS-1:0]                            start_alu,             // Señal de inicio para las alus (1 bit por alu)
    output [NUM_F_ALUS-1:0]                          start_f_alu,			// Señal de inicio para las alus float (1 bit por alu float)
    output [1:0]                                     control_esc,           // Salida para enviar a las unidades de cálculo el control escalar
    
    // MASK
    output [MVL-1:0]                                 mask_o,                // Salida para la máscara
    // Como los registros pueden tener dos puertos de escritura, usamos un mux para elegir de qué
    // puerto vamos a copiar la máscara
    output                                           start_mux_mask,        // Señal de inicio del mux para copiar máscara
    output [bitwidth(NUM_WRITE_PORTS)-1:0]           mask_mux_sel,          // Señal de seleccion del mux para copiar máscara
    // MUL
    output [NUM_MULS-1:0]                            start_mul,             // Señal de inicio de los multiplicadores
    output [NUM_F_MULS-1:0]                          start_f_mul,			// Señal de inicio de los multiplicadores float
    // DIV
    output [NUM_DIVS-1:0]                            start_div,				// Señal de inicio de los divisores
    output [NUM_F_DIVS-1:0]                          start_f_div,			// Señal de inicio de los divisores float
    output                                           op_div,                // Selector de operacion de divisor entero (division o resto)
    //	SQRT
    output [NUM_SQRTS-1:0]                           start_sqrt,			// Señal de inicio de los operadores sqrt
    output [NUM_F_SQRTS-1:0]                         start_f_sqrt,			// Señal de inicio de los operadores sqrt float
    // ADDMUL
    output [NUM_F_ADDMULS-1:0]                       start_f_addmul,        // OBSOLETO
    // LOGIC
    output [NUM_LOGICS-1:0]                          start_logic,           // Señal de inicio de los operadore multifuncion
    output [NUM_LOGIC_OPS-1:0]                       sel_logic_op,			// Señal de selección de la operacion a realizar en operador multifuncion
                                                                            // se comparte entre todos y solo lo captura el que reciba la señal de inicio
    // Muxes
    // Mux ALUs
    output [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0]   alu_mux_sel_op1,   	// Señal de selección del multiplexor del operando 1 de las unidades de cálculo
    output [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0]   alu_mux_sel_op2,		// Señal de selección del multiplexor del operando 2 de las unidades de cálculo
                                                                            // De nuevo comparten todos señal de selección, pero solo la capturaran los que reciban señal de inicio
                                                                            // (se usa la misma señal que para iniciar el operador)
    // Mux Mem/load/store
    output [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0]   mem_mux_sel,			// Señal de selección del multiplexor de escritura en memoria:
                                                                            // para elegir entre todas las salidas de los registros vectoriales
                                                                            // Este mux se activa con la señal de escritura de memoria
    // Mux Write registers
    output [bitwidth(NUM_ALUS+NUM_MULS+NUM_DIVS+
            NUM_SQRTS+NUM_F_ALUS+NUM_F_MULS+
            NUM_F_DIVS+NUM_F_SQRTS+NUM_LOGICS+
            MEM_READ_PORTS)-1:0]                     bank_write_sel,        // Señales de escritura de los registros vectoriales, agrupadas por registros
    output start_esc_mux,                                                   // Señal de inicio del multiplexor que elige entre los resultados de las unidades
                                                                            // de cálculo para enviar el resultado hacia el banco de registros escalares
    output [bitwidth(NUM_ALUS+NUM_MULS+NUM_DIVS+
            NUM_SQRTS+NUM_F_ALUS+NUM_F_MULS+
            NUM_F_DIVS+NUM_F_SQRTS+NUM_LOGICS+
            MEM_READ_PORTS)-1:0]                     esc_mux_sel,           // Señal de selección del multiplexor que elige entre los resultados de las unidades
                                                                            // de cálculo para enviar el resultado hacia el banco de registros escalares
    output                                           stalling               // Señal de parada (para informar a la FIFO)
);
    
    wire [NUM_READ_PORTS-1:0]  busy_r_per_reg [0:NUM_REGS-1];                   // Wire para separar los busys de los puertos de lectura de cada registro en entradas distintas
    wire [NUM_WRITE_PORTS-1:0] busy_w_per_reg [0:NUM_REGS-1];					// Wire para separar los busys de los puertos de escritura de cada registro en entradas distintas
                                                                                //  (busy_r/w_per_reg[0] contendra los busys de los puertos del registro 0
                                                                                //  (busy_r/w_per_reg[1] contendra los busys de los puertos del registro 1
                                                                                //  ...
    																																
    wire mem_read_available;                                                    // Wire para indicar que hay puerto de lectura de memoria disponible
    wire mem_read_sel;                                                          // Wire que indica qué puerto de lectura se usa (0 primero, 1 segundo)
    wire mem_inst = load | iload | store | istore;                              // Wire para indicar instruccion de acceso a memoria

    reg src1_port_available;													// Registro para indicar si hay algun puerto de lectura del registro vectorial fuente 1 disponible
    reg [bitwidth(NUM_READ_PORTS)-1:0] read_port_op1;				            // Registro para indicar qué puerto de lectura del registro vectorial source 1 está disponible
    reg src2_port_available;													// Registro para indicar si hay algun puerto de lectura del registro vectorial fuente 2 disponible
    reg [bitwidth(NUM_READ_PORTS)-1:0] read_port_op2;				            // Registro para indicar qué puerto de lectura del registro vectorial source 2 está disponible
    reg dst_port_available;														// Registro para indicar si hay algun puerto de escritura del registro vectorial destino disponible
    reg [bitwidth(NUM_WRITE_PORTS)-1:0] write_port;					            // Registro para indicar qué puerto de escritura del registro vectorial destino está disponible
    reg alu_available;															// Registro para indicar si hay alguna alu libre
    reg alu_f_available;														// Registro para indicar si hay alguna alu float libre
    reg [bitwidth(NUM_ALUS)-1:0] alu;											// Registro para indicar qué alu está libre
    reg [bitwidth(NUM_F_ALUS)-1:0] alu_f;										// Registro para indicar qué alu float está libre
    reg mul_available;															// Registro para indicar si hay algun multiplicador libre
    reg mul_f_available;														// Registro para indicar si hay algun multiplicador float libre
    reg [bitwidth(NUM_MULS)-1:0] mul_r;											// Registro para indicar qué multiplicador está libre
    reg [bitwidth(NUM_F_MULS)-1:0] mul_f_r;									    // Registro para indicar qué multiplicador float está libre
    reg div_available;															// Registro para indicar si hay algun divisor libre
    reg div_f_available;														// Registro para indicar si hay algun divisor float libre
    reg [bitwidth(NUM_DIVS)-1:0] div_r;											// Registro para indicar qué divisor está libre
    reg [bitwidth(NUM_F_DIVS)-1:0] div_f_r;									    // Registro para indicar qué divisor float está libre
    reg sqrt_available;															// Registro para indicar si hay sqrt libre
    reg sqrt_f_available;														// Registro para indicar si hay sqrt float libre
    reg [bitwidth(NUM_SQRTS)-1:0] sqrt_r;										// Registro para indicar qué sqrt está libre
    reg [bitwidth(NUM_F_SQRTS)-1:0] sqrt_f_r;								    // Registro para indicar qué sqrt float está libre
    reg logic_available;														// Registro para indicar si hay algun operador multifuncion libre
    reg [bitwidth(NUM_LOGICS)-1:0] logic_r;									    // Registro para indicar qué operador multifunción está libre
    reg addmul_f_available;														// Registro para indicar si hay algun addmul float libre (no se usa)
    reg [bitwidth(NUM_F_ADDMULS)-1:0] addmul_f_r;						        // Registro para indicar qué addmul float está libre (no se usa)
    
    wire setvl_signal;                                      // Señal setvl para modificar el vlr
    
    wire src1_raw;											// Wire para indicar si hay dependencia read_after_write con el registro fuente 1
    wire src2_raw;											// Wire para indicar si hay dependencia read_after_write con el registro fuente 2
    wire dst_waw;											// Wire para indicar si hay dependencia write_after_write con el registro destino
    
    wire [NUM_REGS-1:0] reading;							// Wire auxiliar que indica si se está leyendo de algun registro (un bit por registro)
    wire [NUM_REGS-1:0] writing;							// Wire auxiliar que indica si se está escribiendo en algun registro (un bit por registro)
    
    wire logic_op;                                          // Wire para agrupar instrucciones a ejecutar usando el operador multifuncion
     
    wire ready_setvl;                                       // Wire para indicar que se puede ejecutar la instruccion setvl
    wire ready_aritm;										// Wire para indicar que se puede ejecutar la instruccion aritmética (no hay dependencias o había pero ya no hay)
    wire ready_mul;											// Wire para indicar que se puede ejecutar la multiplicacion (no hay dependencias o había pero ya no hay)
    wire ready_div;											// Wire para indicar que se puede ejecutar la division/modulo (no hay dependencias o había pero ya no hay)
    wire ready_sqrt;										// Wire para indicar que se puede ejecutar la raiz cuadrada (no hay dependencias o habia pero ya no hay)
    wire ready_logic;										// Wire para indicar que se puede ejecutar instrucción en el operador multifuncion (no hay dependencias o había pero ya no hay)
    wire addmul_ready;                                      // Wire para indicar que se puede ejecutar la addmul (no se usa)
    wire ready_read_mem;									// Wire para indicar que se puede ejecutar la lectura de memoria (no hay dependencias o había pero ya no hay)
    wire ready_write_mem;									// Wire para indicar que se puede ejecutar la escritura en memoria (no hay dependencias o había pero ya no hay)
    
    
    wire [MVL-1:0] current_mask;							// Wire para almacenar la salida del registro de máscara (este registro está instanciado y explicado más abajo)
    wire mask_ready;										// Wire que indica que la máscara está lista para ser usada
    wire busy_mask_write;									// Wire que indica que se está escribiendo la máscara sobre el registro de máscara
    
    
    
    // En este generate se generan las entradas de los wires reading y writing
    // Se itera a través de todos los registros, y para cada uno se hace una or con todos sus bits del wire busy_r_per_reg
    // guardando el resultado en la posición indicada por las variables ring/wing
    // De esta forma, si alguno de los puertos del registro está busy, el resultado de la expresión será 1,
    // y ese 1 se quedará en la posición indicada por las variables "ring" o "wing" del wire reading/writing
    generate
        genvar ring;
        genvar wing;
        for (ring = 0; ring < NUM_REGS; ring = ring+1) begin: reading_gen
            assign reading[ring] = |busy_r_per_reg[ring];
        end
        for (wing = 0; wing < NUM_REGS; wing = wing+1) begin: writing_gen
            assign writing[wing] = |busy_w_per_reg[wing];
        end
    endgenerate
    
    // Cualquier operacion lógica se engloba dentro de logic_op, y se ejecuta en el operador multifuncion
    assign logic_op = peq | pne | plt | sll | srl | sra | log_xor | log_or | log_and | sgnj | sgnjn | sgnjx | pxor | por | pand;
    
    
    
    // Generate para separar los busy bits de los puertos de lectura de cada registro
    // En bank_r_busy se reciben todos los busys de todos los puertos de lectura de todos los registros
    // En este generate, se toman los busys de los puertos de lectura de cada registro y se almacenan en una entrada de busy_r_per_reg
    // busy_r_per_reg[0] contendrá los busy bits de los puertos de lectura del registro 0
    // busy_r_per_reg[1] contendrá los busy bits de los puertos de lectura del registro 1
    // ...
    generate
        genvar brpr;
        for (brpr = 0; brpr < NUM_REGS; brpr = brpr+1) begin: busy_r_per_reg_gen
            assign busy_r_per_reg[brpr] = bank_r_busy[NUM_READ_PORTS * (brpr+1) - 1 : NUM_READ_PORTS * brpr];
        end
    endgenerate
    
    // Igual que lo anterior pero para los puertos de escritura
    generate
        genvar bwpr;
        for (bwpr = 0; bwpr < NUM_REGS; bwpr = bwpr+1) begin: busy_w_per_reg_gen
            assign busy_w_per_reg[bwpr] = bank_w_busy[NUM_WRITE_PORTS * (bwpr+1) - 1 : NUM_WRITE_PORTS * bwpr];
        end
    endgenerate
    
    
    // Dependencias
    // Si se está escribiendo sobre el fuente 1 y el primer elemento no está listo, o hay que usar fuente escalar y el registro está esperando a ser escrito; hay RAW
    assign src1_raw = (writing[src1] & ~first_elem[src1] & (~esc[1] | (esc[1] & esc[0]))) | 
                      (esc[1] & ~esc[0] & esc_w_busy & (src1_esc == esc_reg_busy));
    // Si se está escribiendo sobre el fuente 2 y el primer elemento no está disponible hay RAW (el unico que puede ser escalar es el fuente 1)
    assign src2_raw = (writing[src2] & ~first_elem[src2] & (~esc[1] | (esc[1] & ~esc[0]))) | 
                      (esc[1] & esc[0] & esc_w_busy & (src1_esc == esc_reg_busy));
    // Si se está escribiendo sobre el destino y el primer elemento no está disponible, o si el destino es escalar y ya está esperando resultado; hay WAW
    assign dst_waw = (writing[dst] & ~first_elem[dst]) | (vcpop & esc_w_busy & (dst_esc == esc_reg_busy));
    
    // and de los busys de lectura de memoria, para saber si hay puerto disponible
    assign mem_read_available = ~(&mem_r_busy);
    
    // si solo hay un puerto, o hay dos pero el primero está libre: elegimos el primero (0); si no, elegimos el segundo (1)
    assign mem_read_sel = (MEM_READ_PORTS == 1 || ((MEM_READ_PORTS == 2) & ~mem_r_busy[0])) ? 1'b0 : 1'b1;
    
    
    // TEMPORAL PUEDE CAMBIAR POR OTRA LÓGICA
    // Priority encoder para encontrar la posición del primer busy bit a 0 para el registro vectorial fuente 1 
    // (para saber qué puerto de lectura usar si hay alguno libre (src1_port_available = 1))
    integer i;
    always @(busy_r_per_reg[src1], src1, esc) begin
        // Se inician src1_port_available y read_port_op1 a 0
        src1_port_available = 0;
        read_port_op1 = 0;
        if ((~(&busy_r_per_reg[src1])) | (esc[1] & ~esc[0])) begin
        // Si al hacer una and con todos los busys de los puertos de lectura del registro source1 el resultado es 0
        // quiere decir que hay por lo menos un puerto libre
        // Si esc[1] == 1 (la operacion tiene un argumento que es un escalar) y esc[0] == 0 (el argumento escalar es fuente 1) 
        // src1 está disponible ya que no voy a usar puerto
        // Pongo available a 1
            src1_port_available = 1'b1;
            for (i = NUM_READ_PORTS-1; i >= 0; i = i-1) begin
            // Itero por los puertos en orden descendente, si encuentro un puerto con el busy a 0 me lo guardo en el registro
                if (!busy_r_per_reg[src1][i]) begin
                    read_port_op1 = i;
                end
            // Al finalizar las iteraciones, tendré guardado cuál es el puerto disponible (si hay más de uno, tendré el máx próximo a 0)
            end
        end
    end
    
    // Los siguientes bloques always hacen exactamente lo mismo que el de arriba pero para encontrar:
    // Puerto de lectura del src2
    // Puerto de escritura del dst
    // Alguna alu disponible
    // Alguna alu float disponible
    // Algun multiplicador disponible
    // Algun multiplicador float disponible
    // Algun divisor disponible
    // Algun divisor float disponible
    // Algun operador raiz cuadrada disponible
    // Algun operador raiz cuadrada float disponible
    // Algun addmul disponible (NO SE USA)
    // Algun operador multifuncion disponible
    // Algun puerto de lectura de memoria disponible

    always @(busy_r_per_reg[src2], src2, esc) begin
        src2_port_available = 0;
        read_port_op2 = 0;
        if ((~(&busy_r_per_reg[src2]))  |  (esc[1] & esc[0])) begin
            src2_port_available = 1'b1;
            for (i = NUM_READ_PORTS-1; i >= 0; i = i-1) begin
                if (!busy_r_per_reg[src2][i]) begin
                    read_port_op2 = i;
                end
            end
            //end
        end
    end
    
    always @(busy_w_per_reg[dst], dst, vcpop, esc_w_busy) begin
        dst_port_available = 0;
        write_port = 0;
        if (!(&busy_w_per_reg[dst]) | (vcpop & ~esc_w_busy)) begin 
            dst_port_available = 1'b1;
            for (i = NUM_WRITE_PORTS-1; i >= 0; i = i-1) begin
                if (!busy_w_per_reg[dst][i]) begin
                    write_port = i;
                end
            end
        end
    end
    
    always @(alu_busy) begin
        alu_available = 0;
        alu = 0;
        if (!(&alu_busy)) begin
            alu_available = 1'b1;
            for (i = NUM_ALUS-1; i >= 0; i = i-1) begin
                if (!alu_busy[i]) begin
                    alu = i;
                end
            end
        end
    end
    
    always @(alu_f_busy) begin
		alu_f_available = 0;
		alu_f = 0;
		if (!(&alu_f_busy)) begin
			alu_f_available = 1'b1;
			for (i = NUM_F_ALUS-1; i >= 0; i = i-1) begin
				if (!alu_f_busy[i]) begin
					alu_f = i;
				end
			end
		end
	end
    
    always @(mul_busy) begin
        mul_available = 0;
        mul_r = 0;
        if (!(&mul_busy)) begin
            mul_available = 1'b1;
            for (i = NUM_MULS-1; i >= 0; i = i-1) begin
                if (!mul_busy[i]) begin
                    mul_r = i;
                end
            end
        end
    end
    
    always @(mul_f_busy) begin
		mul_f_available = 0;
		mul_f_r = 0;
		if (!(&mul_f_busy)) begin
			mul_f_available = 1'b1;
			for (i = NUM_F_MULS-1; i >= 0; i = i-1) begin
				if (!mul_f_busy[i]) begin
					mul_f_r = i;
				end
			end
		end
	end
    
    always @(div_busy) begin
		div_available = 0;
		div_r = 0;
		if (!(&div_busy)) begin
			div_available = 1'b1;
			for (i = NUM_DIVS-1; i >= 0; i = i-1) begin
				if (!div_busy[i]) begin
					div_r = i;
				end
			end
		end
	end
	
	always @(div_f_busy) begin
		div_f_available = 0;
		div_f_r = 0;
		if (!(&div_f_busy)) begin
			div_f_available = 1'b1;
			for (i = NUM_F_DIVS-1; i >= 0; i = i-1) begin
				if (!div_f_busy[i]) begin
					div_f_r = i;
				end
			end
		end
	end
	
	always @(sqrt_busy) begin
		sqrt_available = 0;
		sqrt_r = 0;
		if (!(&sqrt_busy)) begin
			sqrt_available = 1'b1;
			for (i = NUM_SQRTS-1; i >= 0; i = i-1) begin
				if (!sqrt_busy[i]) begin
					sqrt_r = i;
				end
			end
		end
	end
	
	always @(sqrt_f_busy) begin
		sqrt_f_available = 0;
		sqrt_f_r = 0;
		if (!(&sqrt_f_busy)) begin
			sqrt_f_available = 1'b1;
			for (i = NUM_F_SQRTS-1; i >= 0; i = i-1) begin
				if (!sqrt_f_busy[i]) begin
					sqrt_f_r = i;
				end
			end
		end
	end
	
	always @(addmul_f_busy) begin
		addmul_f_available = 0;
		addmul_f_r = 0;
		if (!(&addmul_f_busy)) begin
			addmul_f_available = 1'b1;
			for (i = NUM_F_ADDMULS-1; i >= 0; i = i-1) begin
				if (!addmul_f_busy[i]) begin
					addmul_f_r = i;
				end
			end
		end
	end
    
    always @(logic_busy) begin
        logic_available = 0;
        logic_r = 0;
        if (!(&logic_busy)) begin
            logic_available = 1'b1;
            for (i = NUM_LOGICS-1; i >= 0; i = i-1) begin
                if (!logic_busy[i]) begin
                    logic_r = i;
                end
            end
        end
    end
    
    
    // Para indicar si se puede cambiar o no el vlr, de momento por si acaso me espero a que no haya ningun operador ocupad
    // (es decir, que no haya ninguna instrucción en ejecución, realmente por la implementación diría que no hace falta esperar)
    assign ready_setvl = (~(|alu_busy) & ~(|mul_busy) & ~(|div_busy) & ~(|sqrt_busy) & ~(|logic_busy) & 
                          ~(|bank_r_busy) & ~(|bank_w_busy) & ~(|mem_r_busy) & ~(mem_w_busy))         &
                          ((~esc_w_busy) | (esc_w_busy & (esc_reg_busy != src1_esc)));
    
    // Ready aritm (suma o resta): si hay alu disponible, puertos disponibles para src1 (lectura), src2 (lectura), dst (escritura), 
    // no RAW en src1, no RAW en src2 y no WAW en dst se puede hacer la op. aritmetica. Tiene en cuenta la variante de enteros y float
    assign ready_aritm = 	(~float) ? 	(alu_available & src1_port_available & src2_port_available & dst_port_available & ~src1_raw & ~src2_raw & ~dst_waw)	:
										(alu_f_available & src1_port_available & src2_port_available & dst_port_available & ~src1_raw & ~src2_raw & ~dst_waw);
    
    // ready mul: igual que para la ALU pero con la multiplicación
    assign ready_mul = (~float)	?	(mul_available & src1_port_available & src2_port_available & dst_port_available & ~src1_raw & ~src2_raw & ~dst_waw)	:
    												(mul_f_available & src1_port_available & src2_port_available & dst_port_available & ~src1_raw & ~src2_raw & ~dst_waw);
    
    // ready div: igual que para la ALU pero con la division/modulo
    assign ready_div = (~float)	?	(div_available & src1_port_available & src2_port_available & dst_port_available & ~src1_raw & ~src1_raw & ~dst_waw) :
    												(div_f_available & src1_port_available & src2_port_available & dst_port_available & ~src1_raw & ~src1_raw & ~dst_waw);
    
    // ready sqrt: igual que para la ALU pero con la sqrt
    assign ready_sqrt = (~float) ?	(sqrt_available & src2_port_available & dst_port_available & ~src2_raw & ~dst_waw) :
    								(sqrt_f_available & src2_port_available & dst_port_available & ~src2_raw & ~dst_waw);
    
    // ready logic: igual que para la ALU pero con el operador multifuncion
    // Aquí se incluyen, a parte de las instrucciones englobadas en el wire "logic_op", las instrucciones vid (generar indices) y vcpop (contar 1s en x registro)
    // Se ponen a parte ya que tienen dependencias propias y no se pueden englobar con las otras
    assign ready_logic = (vid)   ? (logic_available & dst_port_available  & ~dst_waw)                                               : 
                         (vcpop) ? (logic_available & src2_port_available & ~src2_raw & dst_port_available & ~dst_waw)              : 
                                   (logic_available & src1_port_available & src2_port_available & dst_port_available & !src1_raw & !src2_raw & !dst_waw);
    
    // NO SE USA ADDMUL
    assign ready_addmul = (float) ? (addmul_f_available & src1_port_available & src2_port_available & dst_port_available & ~src1_raw & ~src2_raw & ~dst_waw) : 0;
    
    // Ready_read_mem: si hay  puerto de lectura disponible en la unidad load/store, puerto de escritura disponible en dst y no WAW en dst se puede hacer la lectura de memoria
    // En función del tipo de acceso a memoria las dependencias son unas u otras
    // Acceso regular secuencial:
    assign ready_read_mem = (mem_read_available & dst_port_available & ~dst_waw & (~esc_w_busy | (esc_w_busy & src1_esc != esc_reg_busy)) & 
                            ((load & ~strided)                                                           |
                            ( load  & strided & (~esc_w_busy | (esc_w_busy & src2_esc != esc_reg_busy))) | 
                            ( iload & src2_port_available & ~src2_raw)));
                            
//                            ((load & mem_read_available & dst_port_available & ~dst_waw) | 
//                            (iload & src2_port_available & mem_read_available & dst_port_available & ~src2_raw & ~dst_waw)) ? 1'b1 : 1'b0;
    
    // Ready_write_mem: si hay escritura disponible en L/S, puerto de lectura disponible en src1 y no RAW en src1 se puede hacer la escritura en memoria
    assign ready_write_mem = (~mem_w_busy & src1_port_available & ~src1_raw & (~esc_w_busy | (esc_w_busy & src1_esc != esc_reg_busy)) &
                             ((store & ~strided)                                                              |
                             ( store  & strided & (~esc_w_busy | (esc_w_busy & src2_esc != esc_reg_busy)))    |
                             ( istore & src2_port_available & ~src2_raw)));
    

	//  Asignacion de todas las salidas y wires de control para todos los elementos del path
	assign float_signal = float;                                                               // Señal para indicar operacion float
	assign setvl_signal = setvl & ~stalling;                                                   // Señal para modificar registro vlr

    assign mem_w_signal = ((store | istore) & ~stalling) ? 1'b1 : 0; 						   // Instruccion store y no stall -> mando señal escritura memoria
    assign mem_r_signal = ((load | iload ) & ~stalling) ?                                      // Instruccion load y no stall -> mando señal de lectura de memoria
                          (~mem_r_busy[0]) ? 2'b01 : 2'b10 : 0; 							   // Como cada bit corresponde a la señal de un puerto 01 envia señal al puerto 0
                                                                                               // Y 10 envia señal al puerto 1
                                                                                               // 11 (por ejemplo) enviaría señal a ambos puertos a la vez (no hacer)
    
    assign addr_signal = ((store | istore | load | iload) & ~stalling) ? esc_data_i_a : 0;     // Instruccion de memoria y no stall -> se envía la direccion base
                                                                                               // leída de un registro escalar (por ello usamos esc_data_i_a)
    assign stride_out = ((load | store) & ~strided & ~stalling) ? 1'b1 :                       // Instruccion de memoria con acceso regular y no stall -> si es secuencial, se puede generar el propio stride
                        ((load | store) & strided & ~stalling)  ? esc_data_i_b : 0;			   // Si no secuencial, leemos esa separación de un segundo registro escalar
    assign indexed_signal = ((iload | istore) & ~stalling) ? 1'b1 : 0;						   // Si instruccion de memoria con acceso no regular y no stall -> señal de acceso indexada
    assign indexed_st_sel = (istore & ~stalling) ? read_port_op2*NUM_REGS+src2 : 0;	           // Si instruccion de lectura de memoria con acceso no regular y no stall -> señal selección al mux
    assign indexed_ld_sel = (iload & ~stalling) ? read_port_op2*NUM_REGS+src2 : 0;	           // Si instruccion de escritura de memoria con acceso no regular y no stall -> señal selección al mux
    // LÓGICA PARA LA SEÑAL DE SELECCIÓN ANTERIOR
    // En accesos no regulares a memoria, los índices se tienen que leer de un registro vectorial (el indicado por el fuente 2)
    // por lo que hay que generar la señal de selección correspondiente para elegir la sealida del registro y puerto que queremos
    // En read_port_op2 tengo QUÉ puerto leeré del propio registro -> puerto 0, puerto 1, puerto 2... (representados en binario: 00, 01, 10...)
    // Y en src2 tengo qué registro es, si tengo 32 registros tendría 5 bits para representar. Si uso el registro 14, pues será 01110
    // En indexed_st_sel/indexed_ld_sel, se elige entre puertos de registros que están agrupados por puertos, es decir:
    // (ejemplo con 4 registros y 3 puertos de lectura por registro)
    // posicion 0 (0000) -> registro 0 puerto 0
    // posicion 1 (0001) -> registro 1 puerto 0
    // posicion 2 (0010) -> registro 2 puerto 0
    // posicion 3 (0011) -> registro 3 puerto 0
    // posicion 4 (0100) -> registro 0 puerto 1
    // posicion 5 (0101) -> registro 1 puerto 1
    // posicion 6 (0110) -> registro 2 puerto 1
    // posicion 7 (0111) -> registro 3 puerto 1
    // posicion 8 (1000) -> registro 0 puerto 2
    // posicion 9 (1001) -> registro 1 puerto 2
    // posicion 10 (1010) -> registro 2 puerto 2
    // posicion 11 (1011) -> registro 3 puerto 2
    // ...
    
    // Por lo que, para generar la señal se selección, tomo el puerto que tengo disponible, almacenado en read_port_op2
    // y lo multiplico por el número de registros para generar un offset. En el ejemplo anterior, si quiero usar el puerto 1
    // Al multiplicar read_port_op2 (1) por el número de registros (4) el resultado es la posición 4 (0100) que equivale al registro 0 puerto 1
    // Ya estoy en el puerto que quiero, a partir de aquí sumo el registro fuente que quiero usar para llegar a la selección correcta.
    // Quiero leer del registro 3? Sumo 4 (0100) + 3 (0011) y paso a estar en la posición 7, que es el registro 3 puerto 1
    // Quiero leer del puerto 2 del registro 1? puerto (2) * numero de registros (4) = 8 -> Posicion 8: registro 0 puerto 2. Sumo el registro (1) -> 8 + 1 = 9. Posición 9: registro 1 puerto 2
    
    // Esta lógica se usa también para otros casos, con otros tipos de organizaciones. Por ejemplo, si estan organizados al revés (por registros), el offset y la suma se generan también al revés.
    // Multiplicas el registro al que quieres acceder por el número de puertos por registro, (generando asi el offset que te lleva al registro x puerto 0)
    // Y le sumas el puerto al que quieres acceder, llegando al registro x puerto x.
                                                                                           
    
    
    
    
    // Instrucción que genera resultado vectorial y no stall -> se envía señal de escritura al banco de registros vectoriales, aquí se usa lógica similar a la anterior
    // En este caso, no tenemos una señal de selección, sino que tenemos 1 bit para cada registro y puerto. Por ejemplo:
    // 00000001 -> Señal de escritura enviada al puerto 0 del registro 0 
    // 00000010 -> Señal de escritura enviada al puerto 1 del registro 0 
    // 00000100 -> Señal de escritura enviada al puerto 0 del registro 1 
    // 00001000 -> Señal de escritura enviada al puerto 1 del registro 1 
    // 00010000 -> Señal de escritura enviada al puerto 0 del registro 2 
    // 00100000 -> Señal de escritura enviada al puerto 1 del registro 2 
    // 01000000 -> Señal de escritura enviada al puerto 0 del registro 3 
    // 10000000 -> Señal de escritura enviada al puerto 1 del registro 3
    // Por lo que, para generar la señal correcta, ponemos un 1 en la posicion de menor peso (0), y lo desplazamos hasta la posición correcta.
    // El número de desplazamientos es: registro destino * número de puertos por registro (asi generamos el offset) + puerto a usar
    assign bank_w_signal = ((add | sub | load | iload | mul | div | rem | sqrt | logic_op | addmul | vid) && !stalling) ? 1 << dst*NUM_WRITE_PORTS+write_port : 0;
    
    // Instrucción vid y no stall -> enviamos tambien señal de escritura vid al registro correspondiente (misma lógica que en el anterior caso)
    assign masked_vid_signal = (vid & ~stalling) ? 1 << dst*NUM_WRITE_PORTS+write_port : 0;
    
    // Instrucción que tiene que leer registros vectoriales y no stall -> se envian las señales de lectura a los registros correspondientes
    // De nuevo se usa la lógica de poner un 1 y hacer tantos desplazamientos como sea necesario
    // En el caso de tener que enviar dos señales de lectura, se hacen generan la señales de manera independiente y se unen mediante una or.
    // Esto se puede hacer más aseado:
    // Instrucciones que lean dos registros vectoriales -> se envian dos señales
    // Instrucciones que lean solo el vectorial fuente 1 -> se envia una sola señal a ese
    // Instrucciones que lean solo el vectorial fuente 2 -> se envia una sola señal a ese
    assign bank_r_signal = ((add | sub | mul | div | rem | logic_op | addmul | istore) & ~esc[1] & ~stalling) ? 
                                          (1 << src1*NUM_READ_PORTS+read_port_op1 | 1 << src2*NUM_READ_PORTS+read_port_op2) : 
                           ((((add | sub | mul | div | rem | logic_op) & esc[1] & esc[0]) | store) & ~stalling) ? 
                                           1 << src1*NUM_READ_PORTS+read_port_op1 : 
                           ((((add | sub | mul | div | rem | logic_op) & esc[1] & ~esc[0]) | iload | vcpop | sqrt) & ~stalling) ? 
                                           1 << src2*NUM_READ_PORTS+read_port_op2 : 0;
                                           
    
    assign esc_w_en = ((vcpop) & ~stalling);                                            // Instrucción que genera resultado escalar -> se envia señal de escritura al banco escalar
    assign start_esc_mux = ((vcpop) & ~stalling);                                       // Instrucción que genera resultado escalar -> señal de inicio al mux para elegir el resultado
    assign esc_r_en_a = ((esc[1] | setvl | mem_inst) & ~stalling);                      // Instrucción que lee un operando escalar / -> enviar señal de lectura "a"
                                                                                        // Operación "setvl" (el valor se lee de un registro escalar) / -> enviar señal de lectura "a"
                                                                                        // Operacion de memoria (la direccion base se lee de un escalar) -> enviar señal de lectura "a"
    assign esc_r_en_b = (load | store) & strided & ~stalling;                           // Operación de memoria (acceso regular no secuencial, stride leido de un escalar) -> enviar señal de lectura "b"
    assign esc_ra_addr = ((esc[1] | setvl | mem_inst) & ~stalling) ? src1_esc : 0;      // Igual que esc_r_en_a, ahora indicamos qué registro queremos leer
    assign esc_rb_addr = ((store | load) & strided & ~stalling) ? src2_esc : 0;         // Igual que esc_r_en_b, ahora indicamos qué registro queremos leer
    assign esc_w_addr = ((vcpop) & ~stalling) ? dst_esc : 0;                            // Igual que esc_w_en, ahora indicamos qué registro queremos escribir
    assign esc_data_result_o = esc_data_result_i;                                       // El resultado escalar generado nos llega por esc_data_result_i -> lo reenviamos por esc_data_result_o
    assign op = (sub & ~stalling) ? 1'b1 : 1'b0;	 	                                // Instruccion alu y no stall -> si es una suma mando 0; si es una resta mando 1
    
    // El siguiente grupo de señales (quitando op_div) tienen todas la misma lógica y es similar a lo de los 1s desplazados de antes
    // Tengo en las señales alu, alu_f, mul_r, mul_f_r, div_r, div_f_r, sqrt_r, sqrt_f_r y logic_r que indican qué operador está libre para ser utilizado: el 0, el 1...
    // (Igual que hacia antes con los puertos)
    // De nuevo en las señales start, un bit representa cada operador
    // start_alu:
    // 01 -> señal de inicio a la alu 0
    // 10 -> señal de inicio a la alu 1
    // start_f_alu:
    // 01 -> señal de inicio a la alu float 0
    // 10 -> señal de inicio a la alu float 1
    // start_mul:
    // 01 -> señal de inicio al multiplicador 0
    // 10 -> señal de inicio al multiplicador 1
    // ...
    // Ahora no hace falta offset, como en el caso de los puertos y los registros, simplemente se desplaza el 1 tantas veces como indiquen las señales que hemos mencionado
    // Por ejemplo, si la alu 0 está ocupada y la alu 1 está libre, la señal "alu" valdrá 1 y desplazaremos el 1 una vez, enviando así la señal a ese operador: 10
    // Si el divisor 1 está ocupado y el divisor 0 está libre, la señal "div_r" valdrá 0, y desplazaremos el 1 cero veces, enviado así la señal a ese operador: 01
    assign start_alu = ((add | sub) & ~float & ~stalling) ? 1 << alu : 0;               // Instruccion de alu y no stall -> envio señal de inicio a la alu correspondiente
    assign start_f_alu = ((add | sub) & float & ~stalling) ? 1 << alu_f : 0;            // Instruccion de alu float y no stall -> envio señal de inicio a la alu float correspondiente
    assign start_mul = (mul & ~float & ~stalling) ? 1 << mul_r : 0;                     // Instruccion de mult y no stall -> envio señal de inicio al mult correspondiente
    assign start_f_mul = (mul & float & ~stalling) ? 1 << mul_f_r : 0;                  // Instruccion de mult float y no stall -> envio señal de inicio al mult float correspondiente
    assign start_div = ((div | rem) & ~float & ~stalling) ? 1 << div_r : 0;             // Instruccion de div/módulo y no stall -> envio señal de inicio al div correspondiente
    assign start_f_div = (div & float & ~stalling) ? 1 << div_f_r : 0;                  // Instruccion de div float y no stall -> envio señal de inicio al div float correspondiente
    assign op_div = (div & ~stalling) ? 0 : 1;                                          // Instruccion de div y no stall -> 0 division normal; 1 módulo (sólo para enteros)
    assign start_sqrt = (sqrt & ~float & ~stalling) ? 1 << sqrt_r : 0;                  // Instruccion de sqrt y no stall -> envio señal de inicio al sqrt correspondiente
    assign start_f_sqrt = (sqrt & float & ~stalling) ? 1 << sqrt_f_r : 0;               // Instruccion de sqrt float y no stall -> envio señal de inicio al sqrt float correspondiente
    assign start_f_addmul = (addmul & float & ~stalling) ? 1 << addmul_f_r : 0;         // NO SE USA
    assign start_logic = ((logic_op | vid | vcpop) & ~stalling) ? 1 << logic_r : 0;     // Instruccion de logic_op, vid o vcpop y no stall -> envio señal de inicio al oeprador multifuncion correspondiente
    
    // Aquí en función de qué operacion se quiera hacer en el operador multifuncion, se envia una señal de selección u otra
    assign sel_logic_op = 	(peq) 		? 5'b00000	:
                            (pne) 		? 5'b00001	:
                            (plt)		? 5'b00010	:
                            (sll)		? 5'b00011	:
                            (srl)		? 5'b00100	:
                            (sra)		? 5'b00101	:
                            (log_xor )	? 5'b00110	:
                            (log_or)	? 5'b00111	:
                            (log_and)	? 5'b01000	: 
                            (sgnj)		? 5'b01001	:
                            (sgnjn)		? 5'b01010	:
                            (sgnjx)		? 5'b01011	:	
                            (pxor)		? 5'b01100	:
                            (por)	    ? 5'b01101	:
                            (pand)		? 5'b01110	:
                            (vid)       ? 5'b01111  :	
                            (vcpop)     ? 5'b10000  : 0 ;
                            
    // Estas señales de control se envian a los operadores para que sepan qué entradas utilizar
    // control_esc reenvia el control escalar recibido, siempre y cuando no haya stall
    // esc_data_o reenvia el valor escalar que se haya leído del banco de registros escalares
    // mask_o envía una máscara de todo 1s, si la operacion se hace sin máscara; o la máscara del registro auxiliar, si la operacion es con máscara
    assign control_esc = ((add | sub | mul | div | rem | sqrt | logic_op | addmul) & ~stalling) ? esc : 2'b0;
    assign esc_data_o = ((add | sub | mul | div | rem | sqrt | logic_op) & esc[1] & ~stalling  & esc_data_i_a[32]) ? esc_data_i_a : 0;
    assign mask_o = (( add | sub | mul | div | rem | sqrt | logic_op | addmul | vid | vcpop | store | istore | load | iload)  & ~masked_op & ~stalling) ? {MVL{1'b1}} :
                    (((add | sub | mul | div | rem | sqrt | logic_op | addmul | vid | vcpop | store | istore | load | iload)  & masked_op) & ~stalling) ? current_mask : 0;
    
    
    // Si una instrucción escribe sobre v0, inicio el multiplexor para tomar el bit bajo de cada dato e ir copiándolo sobre el registro auxiliar de máscara
    assign start_mux_mask = ((add | sub | mul | div | rem | sqrt | logic_op | addmul | vid) & dst == 0 & ~stalling) ? 1 : 0	;
    // Y para la señal de selección elijo el puerto que va a usar para escribir sobre el registro v0
    assign mask_mux_sel = ((add | sub | mul | div | rem | sqrt | logic_op | addmul | vid) & dst == 0 & ~stalling) ? write_port : 0;
    
    // Instrucción que tiene que leer de registros vectoriales y no sall -> envío la señal de selección
    // Esta señal de selección se genera como he explicado en la linea 600
    // 
    assign alu_mux_sel_op1 = ((add | sub | mul | div | rem | logic_op) & ~stalling)  ? read_port_op1*NUM_REGS+src1 : 0;
    assign alu_mux_sel_op2 = ((add | sub | mul | div | rem | sqrt | logic_op | vcpop) & ~stalling) ? read_port_op2*NUM_REGS+src2 : 0;
    
    // En el caso de instruccion store, hay un multiplexor también para elegir el registro y puerto del que leer los datos que se escribirán en memoria
    // Este registro en la instrucción codificada viene dado por el campo fuente 3 (que en el resto de instrucciones equivale al registro destino), en el codigo del decodificador se ve
    // como este "fuente 3" se mueve al fuente vectorial 1.
    // Y no genera conflicto con el fuente escalar 1 (de donde se lee la dirección base de acceso a memoria)
    assign mem_mux_sel = ((store | istore) & !stalling) ? read_port_op1*NUM_REGS+src1 : 0;
    
    
    // Ahora van las señales de selección de los muxes que están en los puertos de escritura de los registros vectoriales
    // Hay que elegir entre las salidas de TODAS las unidades funcionales y de los puertos de lectura de la load/store
    // Se usa una lógica similar a la vista en la linea 600.
    // Estos muxes tienen concatenadas las salidas de todas las unidades
    // (ejemplo con dos unidades de cada)
    // Posición 0 -> Salida de la alu 0
    // Posición 1 -> Salida de la alu 1
    // Posición 2 -> Salida del mult 0
    // Posición 3 -> Salida del mult 1
    // Posición 4 -> Salida del div 0
    // Posición 5 -> Salida del div 1
    // ...
    // ...
    // Posición n-1 -> Salida del puerto lectura de memoria 0
    // Posición n -> Salida del puerto lectura de memoria 1
    
    // Usaremos un offset y las señales que se han mencionado en la linea 681
    // Ejemplo: Si hemos usado el divisor 1 en la operación, querremos leer su salida. 
    // Tendremos que usar primero un offset que nos posicione en el divisor 0 y luego sumar div_r
    // Con el ejemplo de arriba seria llegar primero a la posición 4 para luego llegar a la 5
    // Se suman todos los operadores que haya antes del divisor -> NUM_ALUS, NUM_MULS
    // Y ahora estamos en la posición 4 (el divisor 0) -> sumamos la señal div_r
    // Como en este caso la señal div_r vale 1 (ya que usamos el divisor 1) 4 + 1 = 5 -> se selecciona la posicion 5, que es la salida del divisor 1
    // Para facilitar estos offsets, se han creado como parametros:
    localparam alu_offset = NUM_ALUS;
    localparam mul_offset = NUM_ALUS+NUM_MULS;
    localparam div_offset = NUM_ALUS+NUM_MULS+NUM_DIVS;
    localparam sqrt_offset = NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS;
    localparam logic_offset = NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS;
    localparam alu_f_offset = NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS+NUM_F_ALUS;																																						
    localparam mul_f_offset = NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS+NUM_F_ALUS+NUM_F_MULS;																																						
    localparam div_f_offset = NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS+NUM_F_ALUS+NUM_F_MULS+NUM_F_DIVS;																																						
    localparam sqrt_f_offset = NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS+NUM_F_ALUS+NUM_F_MULS+NUM_F_DIVS+NUM_F_SQRTS;
    //localparam addmul_f_offset = NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS+NUM_F_ALUS+NUM_F_MULS+NUM_F_DIVS+NUM_F_SQRTS+NUM_F_ADDMULS;														
    assign bank_write_sel = ((add | sub) & ~float & ~stalling) 	? alu	:
                            (mul & ~float & ~stalling)          ? alu_offset + mul_r			 :
                            ((div | rem) & ~float & ~stalling)  ? mul_offset + div_r 			 :
                            (sqrt & ~float & ~stalling)         ? div_offset + sqrt_r			 :
                            ((logic_op | vid) & ~stalling)      ? sqrt_offset + logic_r 		 :
                            ((add | sub) & float & ~stalling)   ? logic_offset + alu_f           :
                            (mul & float & ~stalling)           ? alu_f_offset + mul_f_r		 :
                            (div & float & ~stalling)           ? mul_f_offset + div_f_r		 :
                            (sqrt & float & ~stalling)          ? div_f_offset + sqrt_f_r		 :
                            ((load | iload ) & !stalling)       ? sqrt_f_offset + mem_read_sel   :	0;
    
    // Esta señal de selección es para exactamente lo mismo que la anterior
    // pero en el multiplexor que se enviará hacia el banco de registros escalares
    // (realmente aquuí no haría falta tanta movida, ya que el único operador de momento
    // que genera resultados escalares es el multifunción, pero era muy práctico copiar y
    // pegar el funcionamiento)
    assign esc_mux_sel = ((add | sub) & ~float & ~stalling)  ? alu	                         :
                         (mul & ~float & ~stalling)          ? alu_offset + mul_r			 :
                         ((div | rem) & ~float & ~stalling)  ? mul_offset + div_r 			 :
                         (sqrt & ~float & ~stalling)         ? div_offset + sqrt_r			 :
                         ((logic_op | vid | vcpop) & ~stalling)      ? sqrt_offset + logic_r :
                         ((add | sub) & float & ~stalling)   ? logic_offset + alu_f          :
                         (mul & float & ~stalling)           ? alu_f_offset + mul_f_r		 :
                         (div & float & ~stalling)           ? mul_f_offset + div_f_r		 :
                         (sqrt & float & ~stalling)          ? div_f_offset + sqrt_f_r		 :
                         ((load | iload ) & !stalling)       ? sqrt_f_offset + mem_read_sel  :	0;
    
    // Señal de stall: sirve para indicar que la instrucción actual no se puede realizar
    assign stalling =  (add | sub | load | iload | store | istore | mul | div | rem | sqrt | logic_op | vid | vcpop | setvl) ?  // Primero, stall puede estar activa, siempre y cuando haya
                                                                                                                                // alguna instrucción intentando ser ejecutada
                                                                                                                                // si no hay ninguna, stall valdrá cero
                       // Y ahora simplemente se utilizan las señales ready que se crearon al principio del código
                       (setvl & ~ready_setvl)					      	|          // Si setvl = 1 y ready_setvl = 0 -> stall = 1
    				   ((add | sub) & ~ready_aritm) 					| 	       // Si add o sub = 1 y ready_aritm = 0 -> stall = 1
                       (mul & ~ready_mul)								| 	       // Si mul = 1 y ready_mul = 0 -> stall = 1
                       ((div | rem) & ~ready_div)						|	       // Si div o rem = 1 y ready_div = 0 -> stall = 1
                       (sqrt & ~ready_sqrt)							    |          // Si sqrt = 1 y ready_sqrt = 0 -> stall = 1
                       ((logic_op | vid | vcpop) & ~ready_logic) 	    |	       // Si logic_op o vid o vcpop = 1 y ready_logic = 0 -> stall = 1
                       (addmul & ~ready_addmul)                         |          // NO SE USA
                       ((store | istore) & ~ready_write_mem) 		    | 	       // Si store o istore y ready_write_mem = 0 -> stall = 1
                       ((load  | iload) & ~ready_read_mem) 			    | 	       // Si load o iload y ready_read_mem = 0 -> stall = 1
                       ((masked_op | (dst == 0 & ~store)) & ~mask_ready)	: 0;   // Si operación con máscara 
                                                                                   // u operación con destino 0 (a excepción de la store, ya que no escribe sobre un registro)
                                                                                   // stall -> 1
    																			
    
    // Este es el famoso registro de máscara, está contenido en la unidad de control
    // Cuando se hace una operación que escriba sobre el registro v0, el bit menos significativo
    // de cada elemento del vector se copiará en este registro para formar una máscara
    // que se podrá usar después para realizar operaciones bajo máscara
    mask_vector #(
        .DATA_WIDTH ( 1'b1            ),    // La achura de dato es de 1
        .VALID      ( VALID           ),	// La anchura del valid es de 1
        .MVL        ( MVL             )		// El numero máximo posible de elementos
    ) mv (
        .clk        ( clk             ),	// Señal de reloj
        .rst        ( rst             ),    // Señal de reset
        .VLR        ( VLR             ),	// Número de elementos de vector a operar (es decir cuántos bits se van a escribir)
        .w_signal   ( start_mux_mask  ),	// Señal para preparar el registro para escritura (irá escribiendo los bits conforme vayan llegando)
        .wd_i       ( mask_copy_i     ),	// Entrada por donde irá llegando bit a bit la máscara
        .rd_o       ( current_mask    ),	// Salida de MVL bits para poder leer la máscara completa de golpe (aunque solo serán útiles los VLR primeros bits)
        .busy_write ( busy_mask_write ),	// Salida para indicar que se está escribiendo una máscara
        .mask_ready ( mask_ready      )		// Salida para indicar que la máscara está disponible (o que no se está escribiendo máscara)
    );
    
    
    // Registro vlr que almacena el tamaño del vector con el que se trabaja
    vl_reg #(
    	.MVL      ( MVL                           )    // El tamaño máximo de vector posible
	) vlr_inst (
		.clk      ( clk                           ),   // Señal de reloj
		.rst      ( rst                           ),   // Señal de reset
		.we       ( setvl_signal                  ),   // Señal de habilitar la escritura
		.value_in ( esc_data_i_a[bitwidth(MVL):0] ),   // Valor de entrada a escribir (leído del banco de registros escalares)
		.vlr      ( VLR                           )    // Salida de datos que indica el VLR actual (el valor almacenado en el registro)
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
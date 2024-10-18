`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.10.2023 15:43:13
// Design Name: 
// Module Name: top_reg_mem_alu
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
////////////////////////////////////////////////////////////
// Este modulo es el que se encarga de conectar
// registros vectoriales, load/store, unidades de cálculo
// y recibir y enviar entradas y salidas de la unidad de
// control
// Las entradas y salidas estan organizadas por grupos
////////////////////////////////////////////////////////////

module top_reg_mem_alu #(
    parameter NUM_REGS = 32,
    parameter NUM_WRITE_PORTS = 1,
    parameter NUM_READ_PORTS = 2,
    parameter DATA_WIDTH = 32,
    parameter VALID = 1,
    parameter MASK = 1,
    parameter WIDTH = DATA_WIDTH + VALID, 
    parameter MVL = 32,
    parameter B_ADDRESS = 10,
    parameter MEM_READ_PORTS = 2,
    parameter MAX_STRIDE = 16,
    parameter NUM_ALUS = 2,
    parameter NUM_MULS = 2,
    parameter NUM_DIVS = 2,
    parameter NUM_SQRTS = 2,
    parameter NUM_LOGICS = 2,
    parameter NUM_LOGIC_OPS = bitwidth(18),
    parameter NUM_F_ALUS = 2,
    parameter NUM_F_MULS = 2,
    parameter NUM_F_DIVS = 2,
    parameter NUM_F_SQRTS = 2,
    parameter NUM_F_ADDMULS = 2,
    parameter SEGMENTS = 4
) (
    
    input                                           clk,                // Entrada de reloj
    input                                           rst,                // Señal de reset
    
    /////////  Puertos LS  ///////////
    
    input                                           mem_w_signal,       // Señal de escritura para la memoria
    input [MEM_READ_PORTS-1:0]                      mem_r_signal,       // Señal de lectura para la memoria
    input [bitwidth(MVL):0]                         VLR,                // Señal de VLR
    input                                           float_signal,       // Señal de operacion float
    input [B_ADDRESS-1:0]                           addr,               // Direccion base de lectura/escritura para la load/store
    input [(DATA_WIDTH*MEM_READ_PORTS)-1:0]         mem_data_read_in,   // Entrada de datos leídos de memoria (parte baja puerto 0 de memoria, parte alta puerto 1)
    input [bitwidth(MAX_STRIDE)-1:0]                stride_signal,      // Stride que se usará en la operacion de acceso a memoria (si es acceso regular)
    input                                           indexed_signal,     // Señal de acceso regular o no regular
    input [bitwidth(NUM_REGS*NUM_READ_PORTS)-1:0]   indexed_st_sel,     // Señal de selección del mux para elegir índices de escritura en memoria
    input [bitwidth(NUM_REGS*NUM_READ_PORTS)-1:0]   indexed_ld_sel,     // Señal de selección del mux para elegir índices de lectura en memoria
    
    ///////  Puertos REGS  /////////
    
    // En estas señales, cada bit corresponde a 1 puerto (codificación one-hot)
    // Y estan agrupados en orden
    // [0] -> registro 0 puerto 0
    // [1] -> registro 0 puerto 1
    // [2] -> registro 1 puerto 0
    // [3] -> registro 1 puerto 1
    // ...
    input [NUM_WRITE_PORTS*NUM_REGS-1:0]            bank_w_signal,      // Bus de señales de escritura para los registros, tantos bits como registros * puert. escritura
    input [NUM_WRITE_PORTS*NUM_REGS-1:0]            masked_vid_signal,  // Bus de señales de escritura vid para los registros, tantos bits como registros * puert. escritura
    input [NUM_READ_PORTS*NUM_REGS-1:0]             bank_r_signal,      // Bus de señales de lectura para los registros, tantos bits como registros * puert. lectura
    
    // Estos dos buses no hace falta tener uno para cada multiplexor distinto que haya (seria un bus demasiado grande)
    // Pueden todos compartir la misma entrada de selección, pero solo los que reciban la señal de "start" la leerán
    // y almacenaran
    // Se usan para seleccionar entre las salidas de los registros
    input [bitwidth(NUM_REGS*NUM_READ_PORTS)-1:0]   alu_mux_sel_op1,    // Bus que contiene la selección del MUX de operando1 en las unidades funcionales
    input [bitwidth(NUM_REGS*NUM_READ_PORTS)-1:0]   alu_mux_sel_op2,    // Bus que contiene la seleccion del MUX de operando2 en las unidades funcionales
    
    // Se usa para seleccionar entre las salidas de los registros, pero para la memoria, no los operadores
    input [bitwidth(NUM_REGS*NUM_READ_PORTS)-1:0]   mem_mux_sel,        // Bus que contiene la selección del MUX de escritura en memoria
    
    // Aquí lo mismo que antes, hay un mux por cada puerto de escritura, pero pueden compartir todos seleccion
    // y solo la leen y almacenan los que reciban señal de start
    // Se usa para seleccionar entre las salidas de las alus, multiplicadores, etc. y las salidas de memoria
    input [bitwidth(NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+
                    NUM_F_ALUS+NUM_F_MULS+NUM_F_DIVS+NUM_F_SQRTS+
                    NUM_LOGICS+MEM_READ_PORTS)-1:0] bank_write_sel,     // Bus que contiene la selección del MUX de escritura en registro
    
    input                                           start_esc_mux,      // Señal de inicio del multiplexor que elige la salida a enviar al banco de reg. escalares
    
    // De nuevo, esta señal de selección, elige entre las salidas de todos los operadores
    input [bitwidth(NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+
                    NUM_F_ALUS+NUM_F_MULS+NUM_F_DIVS+NUM_F_SQRTS+
                    NUM_LOGICS+MEM_READ_PORTS)-1:0] esc_mux_sel,
    
    input [1:0]                                     control_esc,                                            // Control escalar: 
                                                                        // 01 o 00 no operando escalar
                                                                        // 10 operando escalar en src1
                                                                        // 11 operando escalar en src2
    input [VALID+DATA_WIDTH-1:0]                    operand_esc,        // Entrada del operando escalar
    
    input [NUM_ALUS-1:0]                            start_alu,          // Señal para iniciar x alu (1 bit por alu)
    input [NUM_F_ALUS-1:0]                          start_f_alu,        // Señal para inicar x alu_float (1 bit por alu float)
    input                                           opcode,             // Señal para indicar si suma o resta (0 suma / 1 resta)
    
    
    // IGUAL QUE EN LA ALU
    input [NUM_MULS-1:0]                            start_mul,
    input [NUM_F_MULS-1:0]                          start_f_mul,
    
    // IGUAL QUE EN LA ALU
    input [NUM_DIVS-1:0]                            start_div,
    input [NUM_F_DIVS-1:0]                          start_f_div,
    input                                           op_div,             // Señal de selección de operacion en caso de division de enteros -> 0 division, 1 modulo
    
    // IGUAL QUE EN LA ALU
    input [NUM_SQRTS-1:0]                           start_sqrt,
    input [NUM_F_SQRTS-1:0]                         start_f_sqrt,
    
    // IGUAL QUE EN LA ALU PERO NO SE USA
    input [NUM_F_ADDMULS-1:0]                       start_f_addmul,
    
    // IGUAL QUE EN LA ALU
    input [NUM_LOGICS-1:0]                          start_logic,
    input [NUM_LOGIC_OPS-1:0]                       sel_logic_op,       // Señal de selección de operacion del operador multifunción
    
    input                                           start_mux_mask,     // Señal para iniciar el multiplexor de máscara
    input [MVL-1:0]                                 mask,               // La máscara a aplicar en caso de operación con máscara (1 escribe / 0 no escribe)
    
    input [bitwidth(NUM_WRITE_PORTS)-1:0]           mask_mux_sel,       // Bus que contiene la selección del multiplexor de máscara (se elige entre los distintos
                                                                        // puertos de escritura del registro vectorial v0)
    
    output [WIDTH+MASK-1:0]                         mem_data_write_out, // Salida de los datos a escribir en memoria
    output [B_ADDRESS-1:0]                          addr_write,         // Salida de la direccion de escritura en memoria
    output [(B_ADDRESS*MEM_READ_PORTS)-1:0]         addr_read,          // Salida de la direccion de lectura de memoria
    output                                          mem_busy_w,         // Señal puerto de escritura de memoria busy
    output [MEM_READ_PORTS-1:0]                     mem_busy_r,         // Señal puertos de lectura de memoria busy
    
    ///////  Puertos REGS  /////////
    
    output [NUM_WRITE_PORTS*NUM_REGS-1:0]           bank_w_busy,        // Bus de señales de escritura busy para registros, tantos bits como registros * puert. escritura
    output [NUM_READ_PORTS*NUM_REGS-1:0]            bank_r_busy,        // Bus de señales de lectura busy para registros, tantos bits como registros * puert. lectura
    
    output [NUM_REGS-1:0]                           first_elem,         // Indica si el primer elemento del registro está disponible, 1 bit por registro
                                                                        
    ///////  Puertos operadores  ///////    
    
    output [NUM_ALUS-1:0]                           alu_busy,           // Señal para indicar que x alu está ocupada (1 bit por alu)
    output [NUM_F_ALUS-1:0]                         alu_f_busy,         // Señal para indicar que x alu flaot está ocupada (1 bit por alu float)
    
    output [NUM_MULS-1:0]                           mul_busy,                                     
    output [NUM_F_MULS-1:0]                         mul_f_busy,
    
    output [NUM_DIVS-1:0]                           div_busy,
    output [NUM_F_DIVS-1:0]                         div_f_busy,
    
    output [NUM_SQRTS-1:0]                          sqrt_busy,
    output [NUM_F_SQRTS-1:0]                        sqrt_f_busy,
    
    output [NUM_F_ADDMULS-1:0]                      addmul_f_busy,
    
    output [NUM_LOGICS-1:0]                         logic_busy,
    
    output [VALID+MASK-1:0]                         mask_bit_o,         // Salida de un bit para ir copiando la máscara que se almacena en v0 ciclo a ciclo sobre
                                                                        // el registro de máscara que hay en la unidad de control
    output [DATA_WIDTH+VALID+MASK-1:0]              esc_result          // Salida del resultado escalar generado
);

    wire [WIDTH-1:0]                              mem_data_i;            // Dato seleccionado para escribir en memoria
    wire [((WIDTH+MASK)*MEM_READ_PORTS)-1:0]      mem_data_o;            // Dato leído de memoria
    wire [((B_ADDRESS+VALID)*MEM_READ_PORTS)-1:0] index_load;            // Índices de lectura a enviar a la unidad load/store
    wire [B_ADDRESS+VALID-1:0] index_store;                              // Indice de escritura a enviar a la unidad load/store
    
    wire [NUM_WRITE_PORTS-1:0]    reg_w_signal          [0:NUM_REGS-1];  // Wire para separar las señales de escritura de cada registro
                                                                         // reg_w_signal[0] almacena las señales de escritura de los puertos de escritura del reg 0
                                                                         // reg_w_signal[1] almacena las señales de escritura de los puertos de escritura del reg 1
                                                                         // ...
    wire [NUM_WRITE_PORTS-1:0]    reg_masked_vid_signal [0:NUM_REGS-1];  // Wire para separar las señales de escritura vid de cada registro
    wire [NUM_READ_PORTS-1:0]     reg_r_signal          [0:NUM_REGS-1];  // Wire para separar las señales de lectura de cada registro                                                                                                                    
                                                                         // reg_r_signal[0] almacena las señales de lectura de los puertos de lectura del reg 0                                                 
                                                                         // reg_r_signal[1] almacena las señales de lectura de los puertos de lectura del reg 1                                                 
                                                                         // ...                                                                                                                                     
    wire [NUM_WRITE_PORTS-1:0]    reg_w_busy            [0:NUM_REGS-1];  // Wire para separar las señales busy de escritura de cada registro
                                                                         // reg_w_busy[0] almacena las señales busy de los puertos de escritura del reg 0
                                                                         // reg_w_busy[1] almacena las señales busy de los puertos de escritura del reg 1
                                                                         // ...
    wire [NUM_READ_PORTS-1:0]     reg_r_busy            [0:NUM_REGS-1];  // Wire para separar las señales busy de lectura de cada registro                                                                                                               
                                                                         // reg_r_busy[0] almacena las señales busy de los puertos de lectura del reg 0                                              
                                                                         // reg_r_busy[1] almacena las señales busy de los puertos de lectura del reg 1                                              
                                                                         // ...                                                                                                                        
    wire [WIDTH-1:0]              alu1                  [0:NUM_ALUS-1];  // Wire para separar el operando 1 de cada alu
                                                                         // alu1[0] tiene el operando 1 de la alu 0
                                                                         // alu1[1] tiene el operando 1 de la alu 1
                                                                         // ...
    wire [WIDTH-1:0]              alu2                  [0:NUM_ALUS-1];  // Wire para separar el operando 2 de cada alu
                                                                         // alu2[0] tiene el operando 2 de la alu 0
                                                                         // alu2[1] tiene el operando 2 de la alu 1
                                                                         // ...
    wire [WIDTH+MASK-1:0]         alu_out               [0:NUM_ALUS-1];  // Wire para spearar el resultado de cada alu
                                                                         // alu_out[0] tien el resultado de la alu 0
                                                                         // alu_out[1] tien el resultado de la alu 1
                                                                         // ...
    // Estos wires siguen la misma dinámica
    wire [WIDTH-1:0]              alu_f_1           [0:NUM_F_ALUS-1];
    wire [WIDTH-1:0]              alu_f_2           [0:NUM_F_ALUS-1];
    wire [WIDTH+MASK-1:0]         alu_f_out         [0:NUM_F_ALUS-1];
    wire [WIDTH-1:0]              mul1              [0:NUM_MULS-1];
    wire [WIDTH-1:0]              mul2              [0:NUM_MULS-1];
    wire [WIDTH+MASK-1:0]         mul_out           [0:NUM_MULS-1];
    wire [WIDTH-1:0]              mul_f_1           [0:NUM_F_MULS-1];
    wire [WIDTH-1:0]              mul_f_2           [0:NUM_F_MULS-1];
    wire [WIDTH+MASK-1:0]         mul_f_out         [0:NUM_F_MULS-1];
    wire [WIDTH-1:0]              div1              [0:NUM_DIVS-1];
    wire [WIDTH-1:0]              div2              [0:NUM_DIVS-1];
    wire [WIDTH+MASK-1:0]         div_out           [0:NUM_DIVS-1];
    wire [WIDTH-1:0]              div_f_1           [0:NUM_F_DIVS-1];
    wire [WIDTH-1:0]              div_f_2           [0:NUM_F_DIVS-1];
    wire [WIDTH+MASK-1:0]         div_f_out         [0:NUM_F_DIVS-1];
    wire [WIDTH-1:0]              sqrt1             [0:NUM_SQRTS-1];
    wire [WIDTH+MASK-1:0]         sqrt_out          [0:NUM_SQRTS-1];
    wire [WIDTH-1:0]              sqrt_f_1          [0:NUM_F_SQRTS-1];
    wire [WIDTH+MASK-1:0]         sqrt_f_out        [0:NUM_F_SQRTS-1];
    wire [WIDTH-1:0]              logic1            [0:NUM_LOGICS-1];
    wire [WIDTH-1:0]              logic2            [0:NUM_LOGICS-1];
    wire [WIDTH+MASK-1:0]         logic_out         [0:NUM_LOGICS-1];
    
    
    wire [(WIDTH+MASK)*(NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS+
          NUM_F_ALUS+NUM_F_MULS+NUM_F_DIVS+NUM_F_SQRTS+MEM_READ_PORTS)-1:0] write_per_reg;      // Buffer que concatena la salida de todas las unidades de cálculo y la salida de memoria
                                                                                                // para hacer de entrada en los multiplexores de escritura sobre registro
    wire [(WIDTH+MASK)*NUM_WRITE_PORTS-1:0] reg_wd_i[0:NUM_REGS-1];                             // Buffer que contiene los datos de entrada para la escritura sobre cada registro
                                                                                                // reg_wd_i[0] contiene los datos de escritura sobre el registro 0 (para todos sus puertos)
                                                                                                // reg_wd_i[1] contiene los datos de escritura sobre el registro 1 (para todos sus puertos)
                                                                                                // ...
    wire [WIDTH*NUM_READ_PORTS-1:0]  read_per_reg_o[0:NUM_REGS-1];                              // Buffer que contiene la salida de lectura de cada registro
                                                                                                // read_per_reg_o[0] contiene la salida de lectura del registro 0 (para todos sus puertos)
                                                                                                // read_per_reg_o[1] contiene la salida de lectura del registro 1 (para todos sus puertos)
                                                                                                // ...
    wire [(WIDTH*NUM_READ_PORTS)*NUM_REGS-1:0] reg_rd_o_g;                                      // Buffer que contiene las salidas los registros agrupadas por puertos (es la entrada de los 
                                                                                                // multiplexores para los operadores y la memoria)
                                                                                                // e.g. (pongamos que hay 2 registros con 2 puertos de lectura cada uno):
                                                                                                // [...reg1.puerto1 + reg0.puerto1 + reg1.puerto0 + reg0.puerto0]
    wire [((B_ADDRESS+VALID)*NUM_READ_PORTS)*NUM_REGS-1:0] indexed_mux_in;                      // Igual que reg_rd_o_g, pero quitando los bits más altos
                                                                                                // Como esto se usa para los índices, estos índices pueden tener un tamaño máximo en bits = DEPTH
                                                                                                // Pues en este wire se almacenan los mismos datos que en reg_rd_o_g pero sólo valid + primeros DEPTH bits
                                                                                                // Es la entrada de los multiplexores que eligen indices para los accesos a memoria

    
    // Este generate se encarga de implementar el comportamiento especificado para reg_w_signal y reg_masked_vid_signal (funcionan igual)
    // Toma los datos de bank_w_signal y los va agrupando en las entradas de reg_w_signal y reg_masked_vid_signal
    // A veces uso la convención "+:"
    // funciona así (lo vi en una pagina web)
    // reg [31:0] dword;
    // reg [7:0] byte0;
    // assign byte0 = dword[0 +: 8];    // Same as dword[7:0]
    // Es decir, con la parte izquierda defines la posicion del bit más bajo, 
    // y con la derecha indicas a partir de ahi a cuántas posiciones se accede
    
    // En este de ahora por ejemplo uso [NUM_WRITE_PORTS*i +: NUM_WRITE_PORTS]
    // A partir del bit NUM_WRITE_PORTS*i se accede hasta (NUM_WRITE_PORTS*i + NUM_WRITE_PORTS)-1
    // O lo que seria lo mismo, de NUM_WRITE_PORTS*i a (NUM_WRITE_PORTS * (i+1)) -1
    // Al principio no usaba +:, luego lo fui cambiando en algunas cosas que era trivial
    // En otros casos el tema de jugar con los índices es más dificil y no está cambiado
    // En los casos en los que está cambiado, aparece encima (o debajo) el equivalente sin "+:"
    generate
        genvar i;
        for ( i= 0; i < NUM_REGS; i = i+1) begin: w_signal_wires
            //assign reg_w_signal[i] = bank_w_signal[NUM_WRITE_PORTS * (i + 1) - 1 : NUM_WRITE_PORTS * i];
            assign reg_w_signal[i] = bank_w_signal[NUM_WRITE_PORTS*i +: NUM_WRITE_PORTS];
            assign reg_masked_vid_signal[i] = masked_vid_signal[NUM_WRITE_PORTS*i +: NUM_WRITE_PORTS];
        end
    endgenerate
    
    // Este generate se encarga de implementar el comportamiento especificado para reg_r_signal
    // Toma los datos de bank_r_signal y los va agrupando en las entradas de reg_r_signal
    generate
        genvar j;
        for (j = 0; j < NUM_REGS; j = j+1) begin: r_signal_wires
            //assign reg_r_signal[j] = bank_r_signal[NUM_READ_PORTS * (j + 1) - 1 : NUM_READ_PORTS * j];
            assign reg_r_signal[j] = bank_r_signal[NUM_READ_PORTS * j +: NUM_READ_PORTS];
        end
    endgenerate
    
    // Este generate se encarga de implementar el comportamiento especificado para bank_w_busy
    // Toma los datos de cada entrada de reg_w_busy (que contiene los busys de los puertos de escritura de un registro) y los concatena en bank_w_busy
    generate
        genvar wb;
        for(wb = 0; wb < NUM_REGS; wb = wb+1) begin: wb_assign
            //assign bank_w_busy[NUM_WRITE_PORTS * wb+NUM_WRITE_PORTS - 1 : NUM_WRITE_PORTS * wb] = reg_w_busy[wb];
            assign bank_w_busy[NUM_WRITE_PORTS * wb +: NUM_WRITE_PORTS] = reg_w_busy[wb];
        end
    endgenerate
    
    // Este generate se encarga de implementar el comportamiento especificado para bank_r_busy
    // Toma los datos de cada entrada de reg_r_busy (que contiene los busys de los puertos de lectura de un registro) y los concatena en bank_r_busy
    generate
        genvar rb;
        for (rb = 0; rb < NUM_REGS; rb = rb+1) begin: rb_assign
            //assign bank_r_busy[NUM_READ_PORTS * rb + NUM_READ_PORTS - 1 : NUM_READ_PORTS * rb] = reg_r_busy[rb];
            assign bank_r_busy[NUM_READ_PORTS * rb +: NUM_READ_PORTS] = reg_r_busy[rb];
        end
    endgenerate
    
    // Este generate se encarga de generar el contenido del wire write_per_reg, que concatena las salidas de todos los operadores y de la memoria
    // para hacer de entrada en los multiplexores de escritura de los registros
    // Es importante tener en cuenta que estos datos que llegan contienen datos de 32 bits + 1 bit de valid + 1 bit de máscara
    generate
        genvar w1;
        genvar w2;
        genvar w3;
        genvar w4;
        genvar w5;
        genvar w6;
        genvar w7;
        genvar w8;
        genvar w9;
        genvar w10;
        localparam alu_offset = (NUM_ALUS*(WIDTH+MASK));                                                                // Offset de hasta dónde llegan los resultados de las alus
        localparam alu_mul_offset = (NUM_ALUS+NUM_MULS)*(WIDTH+MASK);                                                   // Offset de hasta dónde llegan los resultados de los multiplicadores
        localparam alu_mul_div_offset = (NUM_ALUS+NUM_MULS+NUM_DIVS)*(WIDTH+MASK);                                      // Offset de hasta dónde llegan los resultados de los divisores
        localparam alu_mul_div_sqrt_offset = (NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS)*(WIDTH+MASK);                       // Offset de hasta donde llegan los resultados de los sqrts
        localparam alu_mul_div_sqrt_logic_offset = (NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS)*(WIDTH+MASK);      // Offset de hasta dónde llegan los resultados de los comparadores
        localparam alu_f_offset = (NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS
                                                 + NUM_F_ALUS)*(WIDTH+MASK);                                            // Offset de hasta donde llegan los resultados de las alu float
        localparam mul_f_offset = (NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS
                                                  + NUM_F_ALUS + NUM_F_MULS)*(WIDTH+MASK);                              // Offset de hasta donde llegan los resultados de los muls float
        localparam div_f_offset = (NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS
                                                 + NUM_F_ALUS + NUM_F_MULS + NUM_F_DIVS)*(WIDTH+MASK);                  // Offset de hasta donde llegan los resultados de los divs float
        localparam sqrt_f_offset = (NUM_ALUS+NUM_MULS+NUM_DIVS+NUM_SQRTS+NUM_LOGICS
                                                   + NUM_F_ALUS + NUM_F_MULS + NUM_F_DIVS + NUM_F_SQRTS)*(WIDTH+MASK);  // Offset de hasta donde llegan los resultados de los sqrt float
        
        // Primero se agrupan en la parte baja las salidas de las alus
        // Se toman los valores almacenados en alu_out y se van concatenando
        for (w1 = 0; w1 < NUM_ALUS; w1 = w1+1) begin: write_per_reg_alu
            //assign write_per_reg[(WIDTH+MASK) * (w1+1) - 1 : (WIDTH+MASK) * w1] = alu_out[w1];
            assign write_per_reg[(WIDTH+MASK) * w1 +: (WIDTH+MASK)] = alu_out[w1];
        end
        
        // Luego usamos un offset para no sobreescribir la salidas de las alus, y se concatenan las salidas de los multiplicadores
        // Se toman los valores almacenados en mul_out y se van concatenando
        for (w2 = 0; w2 < NUM_MULS; w2 = w2 + 1) begin: write_per_reg_mul
            //assign write_per_reg[((WIDTH+MASK) * (w2+1) - 1) + alu_offset : ((WIDTH+MASK) * w2) + alu_offset] = mul_out[w2];
            assign write_per_reg[((WIDTH+MASK) * w2) + alu_offset +: (WIDTH+MASK)] = mul_out[w2];
        end
        
        // Usamos otro offset para no sobreescribit alus y mults, y luego se concatenan las salidas de los divisores
        // Se toman los valores almacenados en div_out y se van concatenando
        for (w3 = 0; w3 < NUM_DIVS; w3 = w3 + 1) begin: write_per_reg_div
            //assign write_per_reg[((WIDTH+MASK) * (w2+1) - 1) + alu_offset : ((WIDTH+MASK) * w2) + alu_offset] = mul_out[w2];
            assign write_per_reg[((WIDTH+MASK) * w3) + alu_mul_offset +: (WIDTH+MASK)] = div_out[w3];
        end
        
        // Vamos repitiendo el proceso: offset y concatenar las salidas de las raíces
        // Se toman los valores almacenados en sqrt_out y se van concatenando
        for (w4 = 0; w4 < NUM_SQRTS; w4 = w4 + 1) begin: write_per_reg_sqrt
            //assign write_per_reg[((WIDTH+MASK) * (w2+1) - 1) + alu_offset : ((WIDTH+MASK) * w2) + alu_offset] = mul_out[w2];
            assign write_per_reg[((WIDTH+MASK) * w4) + alu_mul_div_offset +: (WIDTH+MASK)] = sqrt_out[w4];
        end
        
        // Offset y concatenar las salidas de los operadores multifunción
        // Se toman los valores almacenados en logic_out y se van concatenando
        for (w5 = 0; w5 < NUM_LOGICS; w5 = w5 + 1) begin: write_per_reg_logic
            assign write_per_reg[((WIDTH+MASK) * w5) + alu_mul_div_sqrt_offset +: (WIDTH+MASK)] = logic_out[w5];
        end
    
        // Offset y concatenar salidas alus float
        for (w6 = 0; w6 < NUM_F_ALUS; w6 = w6 + 1) begin: write_per_reg_alu_f
            //assign write_per_reg[((WIDTH+MASK) * (w2+1) - 1) + alu_offset : ((WIDTH+MASK) * w2) + alu_offset] = mul_out[w2];
            assign write_per_reg[((WIDTH+MASK) * w6) + alu_mul_div_sqrt_logic_offset +: (WIDTH+MASK)] = alu_f_out[w6];
        end
        
        // Offset y concatenar salidas muls float
        for (w7 = 0; w7 < NUM_F_MULS; w7 = w7 + 1) begin: write_per_reg_mul_f
            //assign write_per_reg[((WIDTH+MASK) * (w2+1) - 1) + alu_offset : ((WIDTH+MASK) * w2) + alu_offset] = mul_out[w2];
            assign write_per_reg[((WIDTH+MASK) * w7) + alu_f_offset +: (WIDTH+MASK)] = mul_f_out[w7];
        end
        
        // Offset y concatenar salidas divs float
        for (w8 = 0; w8 < NUM_F_DIVS; w8 = w8 + 1) begin: write_per_reg_div_f
            //assign write_per_reg[((WIDTH+MASK) * (w2+1) - 1) + alu_offset : ((WIDTH+MASK) * w2) + alu_offset] = mul_out[w2];
            assign write_per_reg[((WIDTH+MASK) * w8) + mul_f_offset +: (WIDTH+MASK)] = div_f_out[w8];
        end
        
        // Offset y concatenar salidas sqrts float
        for (w9 = 0; w9 < NUM_F_SQRTS; w9 = w9 + 1) begin: write_per_reg_sqrt_f
            //assign write_per_reg[((WIDTH+MASK) * (w2+1) - 1) + alu_offset : ((WIDTH+MASK) * w2) + alu_offset] = mul_out[w2];
            assign write_per_reg[((WIDTH+MASK) * w9) + div_f_offset +: (WIDTH+MASK)] = sqrt_f_out[w9];
        end
    endgenerate  
    
    // Y finalmente se concatena la salida de memoria en la parte más alta
    assign write_per_reg[sqrt_f_offset +: (WIDTH+MASK)*MEM_READ_PORTS] = mem_data_o;
    
    
    // Generate que se encarga de generar el contenido de reg_rd_o_g
    // Es decir, que concatena las salidas de todos los registros agrupadas por puertos: 
    // registro 0 puerto 0, registro 1 puerto 0, registro 2 puerto 0, 
    // registro 0 puerto 1, registro 1 puerto 1, registro 2 puerto 1...
    generate
        genvar prt;
        genvar rgs;
        // Bucle externo que itera por puertos
        // Cada iteración de este bucle equivale a cada puerto: 0, 1, 2...
        for (prt = 0; prt < NUM_READ_PORTS; prt = prt+1) begin: nested_ports
            // Bucle interno que itera por registros
            // Cada iteración de este bucle equivale a cada registro
            for (rgs = 0; rgs < NUM_REGS; rgs = rgs + 1) begin: inner_read
                // Aquí no usé +:
                // En el wire en el que escribo parto de un offset inicial (prt*WIDTH*NUM_REGS)
                // Si estoy en el primer puerto el offset será -> 0 (valor de prt) * WIDTH * NUM_REGS -> empezaré desde el bit 0
                // Si estoy en el segundo puerto el offset será -> 1 (valor de prt) * WIDTH * NUM_REGS -> me salto todos los bits de los puertos 0,
                // como la salida de cada puerto tiene una anchura de WIDTH, si multiplico esa anchura por el número de registros
                // llego directamente a la primera posición que corresponda al puerto 1 (que será registro 0 puerto 1)
                // Luego a partir de aquí, simplemente voy indexando las posiciones de cada registro usando rgs para escribir la salida de cada registro
                // En el caso de read_oer_reg_o, es más fácil: leo de la entrada rgs y acceso a los datos del puerto que quiero usando prt
                assign reg_rd_o_g[(prt*WIDTH*NUM_REGS)+(rgs+1)*WIDTH-1 : (prt*WIDTH*NUM_REGS)+rgs*WIDTH] = read_per_reg_o[rgs][WIDTH * (prt + 1) - 1 : WIDTH * prt];
            end
        end
    endgenerate
    
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////    
    
    // Este generate es exactamente igual que el de antes, pero como es para índices en vez de usar WIDTH, uso B_ADDRESS+VALID
    // Ya que, como se ha dicho antes, no queremos los 32 bits de dato de los registros, solo los primero B_ADDRESS bits (y el de valid)
    generate
        genvar ind1;
        genvar ind2;
        for (ind1 = 0; ind1 < NUM_READ_PORTS; ind1 = ind1+1) begin: indexed_ports
            // Bucle interno que itera por registros
            for (ind2 = 0; ind2 < NUM_REGS; ind2 = ind2 + 1) begin: indexed_reg
                assign indexed_mux_in[(ind1*NUM_REGS*(B_ADDRESS+VALID))+(ind2*(B_ADDRESS+VALID)) +: B_ADDRESS+VALID] = 
                       {read_per_reg_o[ind2][WIDTH * ind1 + WIDTH - 1],read_per_reg_o[ind2][WIDTH * ind1 +: (B_ADDRESS)]};
            end
        end
    endgenerate
    

    
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    // Aquí comienza la instanciación masiva de todos los módulos del datapath
    
    // Este generate instancia los multiplexores para la escritura en los registros vectoriales
    // Hay un multiplexor por cada puerto de escritura, por lo que hay un total de NUM_REGS*NUM_WRITE_PORTS muxes
    generate
        genvar muxw_r;    // Representa a los registros
        genvar muxw_p;   // Representa a los puertos
        for (muxw_r = 0; muxw_r < NUM_REGS; muxw_r = muxw_r+1) begin: mux_write_reg_gen
            for(muxw_p = 0; muxw_p < NUM_WRITE_PORTS; muxw_p = muxw_p+1) begin: mux_write_ports_gen
                mux_param #(
                    .NUM_INPUTS ( NUM_ALUS + NUM_MULS + NUM_DIVS + NUM_SQRTS + NUM_LOGICS +
                                  NUM_F_ALUS + NUM_F_MULS + NUM_F_DIVS + NUM_F_SQRTS + MEM_READ_PORTS       ),  // Su numero de entradas es igual al numero de operadores + 1 o 2 (puertos lectura memoria)
                    .DATA_WIDTH ( DATA_WIDTH + MASK                                                         ),  // La anchura de dato son los 32 bits + bit máscara (internamente se le suma el valid)
                    .VALID      ( VALID                                                                     ),  // El valid tiene 1 bit de ancho
                    .MVL        ( MVL                                                                       )   // El máximo numero de elementos de un vector
                ) mux_write     (
                    .clk        ( clk                                                                       ),  // Señal de reloj
                    .rst        ( rst                                                                       ),  // Señal de reset
                    .start      ( bank_w_signal[muxw_r * NUM_WRITE_PORTS + muxw_p]                          ),  // Usan como señal de inicio la señal de escritura del registro y puerto correspondiente
                    .data_i     ( write_per_reg                                                             ),  // Usan write_per_reg como entrada -> salidas concatenadas de todos los operadores
                    .sel        ( bank_write_sel                                                            ),  // Usan bank_write_sel como selección
                                                                                                                // Todos comparten entrada y selección, y solo lee realmente el que
                                                                                                                // reciba el start
                    .VLR        ( VLR                                                                       ),  // Dejarán pasar VLR elementos validos
                    .data_o     ( reg_wd_i[muxw_r][(WIDTH+MASK) * (muxw_p + 1) - 1 : (WIDTH+MASK) * muxw_p] )   // Ponen su salida en su posición correspondiente de reg_wd_i[muxw_r]
                );
            end
        end
    endgenerate
    
    // Este mux funciona igual que el anterior pero se usa para seleccionar el resultado escalar
    // que se enviará al banco de registros escalares
    
    mux_param #(
        .NUM_INPUTS ( NUM_ALUS + NUM_MULS + NUM_DIVS + NUM_SQRTS + NUM_LOGICS +
                      NUM_F_ALUS + NUM_F_MULS + NUM_F_DIVS + NUM_F_SQRTS + MEM_READ_PORTS ),    // Su numero de entradas es igual al numero de operadores + 1 (memoria)
        .DATA_WIDTH ( DATA_WIDTH + MASK                                                   ),    // La anchura de dato son los 32 bits + bit máscara (internamente se le suma el valid)
        .VALID      ( VALID                                                               ),    // El valid tiene 1 bit de ancho
        .MVL        ( MVL                                                                 )     // El máximo numero de elementos de un vector
    ) mux_esc_result (
        .clk        ( clk                                                                 ),    // Señal de reloj
        .rst        ( rst                                                                 ),    // Señal de reset
        .start      ( start_esc_mux                                                       ),    // Usa su propia señal de start
        .data_i     ( write_per_reg                                                       ),    // Usa write_per_reg como entrada
        .sel        ( esc_mux_sel                                                         ),    // Usa su propia señal de selección
        .VLR        ( 6'b000001                                                           ),    // Dejará pasar VLR elementos validos (en este caso sólo 1)
        .data_o     ( esc_result                                                          )     // Pone su salida en esc_result
    );
    
    
    
    // Este wire es la entrada para el mux de máscara (que es especial)
    // Este mux recibe como entrada la entrada del registro 0, pero no todo el bus, solo el bit valid y el bit menos significativo de cada puerto
    // Por lo que en este generate, se implementa ese comportamiento
    wire[(MASK+VALID)*NUM_WRITE_PORTS-1:0] lsb_per_port;
    generate
        genvar mb;
        for (mb = 0; mb < NUM_WRITE_PORTS; mb = mb+1) begin: lsb_selection
            // Voy escribiendo sobre el wire de 2 en 2 bits copiando el bit valid: posición (mb+1) * (WIDTH+MASK) - 1, y el lsb: posición mb * (WIDTH+MASK)
            assign lsb_per_port[(MASK+VALID) * mb +: MASK+VALID] = {reg_wd_i[0][mb * (WIDTH+MASK) + WIDTH], reg_wd_i[0][mb * (WIDTH+MASK)]};
            //assign lsb_per_port[(mb+1)*(MASK+VALID) - 1 : (MASK+VALID) * mb] = {reg_wd_i[0][(mb+1) * (WIDTH+MASK) - 1], reg_wd_i[0][mb * (WIDTH+MASK)]};
        end
    endgenerate
    
    // Instanciacion del mask MUX
    mux_param #(
        .NUM_INPUTS ( NUM_WRITE_PORTS ),    // Tiene tantas entradas como puertos de escritura tenga un registro
        .DATA_WIDTH (MASK             ),    // Su anchura de dato es de 1 bit: la máscara (internamente se le suma el valid)
        .VALID      ( VALID           ),    // El valid es de 1 bit
        .MVL        ( MVL             )     // El máximo numero de elementos de un vector
    ) mux_mask (
        .clk        ( clk             ),    // Señal de reloj
        .rst        ( rst             ),    // Señal de reset
        .start      ( start_mux_mask  ),    // Señal de start
        .data_i     ( lsb_per_port    ),    // Dato de entrada: el wire lsb_per_port que contiene los lsb de cada puerto de escritura del registro 0
        .sel        ( mask_mux_sel    ),    // Señal de selección
        .VLR        ( VLR             ),    // Se dejarán pasar VLR elementos
        .data_o     ( mask_bit_o      )     // La salida se escribe sobre mask_bit_o
    );
    
    
    
    // Instanciaciones de los muxes para elegir los operandos de las unidades funcionales
    // 2 muxes por operador
    // Se explicarán las señales para el primer caso, el resto siguen la misma lógica
    
    // Muxes ALUs
    generate
        genvar m;
        for (m = 0; m < NUM_ALUS; m = m+1) begin: alu_muxes
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ),      // Numero de entradas: tantas como registros * puertos de lectura
                .DATA_WIDTH ( DATA_WIDTH                ),      // La anchura del dato es de 32 bits (internamente se suma el valid)
                .VALID      ( VALID                     ),      // Bit de valid
                .MVL        ( MVL                       )       // Tamaño máximo de vector
            ) mux_op1 (
                .clk        ( clk                       ),      // Señal de reloj
                .rst        ( rst                       ),      // Señal de reset
                .start      ( start_alu[m]              ),      // Usan la señal de inicio de su correspondiente alu
                .data_i     ( reg_rd_o_g                ),      // El dato entrante es reg_rd_o_g: las salidas de todos los registros concatenadas y agrupadas por puertos
                .sel        ( alu_mux_sel_op1           ),      // Selección compartida por TODOS los muxes de operando 1 (aunque se llame alu, se usa para todos)
                                                                // Sólo la capturan los muxes que reciban señal de inicio
                .VLR        ( VLR                       ),      // Número de elementos a dejar pasar
                .data_o     ( alu1[m]                   )       // La salida se escribe en la entrada correspondiente del operando 1 del operador
            );
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ),      // Numero de entradas: tantas como registros * puertos de lectura 
                .DATA_WIDTH ( DATA_WIDTH                ),      // La anchura del dato es de 32 bits (internamente se suma el valid)
                .VALID      ( VALID                     ),      // Bit de valid
                .MVL        ( MVL                       )       // Tamaño máximo del vector
            ) mux_op2 (
                .clk        ( clk                       ),      // Señal de reloj
                .rst        ( rst                       ),      // Señal de reset
                .start      ( start_alu[m]              ),      // Usan la señal de inicio de su correspondiente alu
                .data_i     ( reg_rd_o_g                ),      // El dato entrante es reg_rd_o_g: las salidas de todos los registros concatenadas y agrupadas por puertos
                .sel        ( alu_mux_sel_op2           ),      // Selección compartida por TODOS los muxes de operando 2 (aunque se llame alu, se usa para todos)
                                                                // Sólo la capturan los muxes que reciban señal de inicio
                .VLR        ( VLR                       ),      // Número de elementos a dejar pasar
                .data_o     ( alu2[m]                   )       // La salida se escribe en la entrada correspondiente del operando 2 del operador
            );
        end
    endgenerate
    
    
    // Muxes MULs
    generate
        genvar mul;
        for (mul = 0; mul < NUM_MULS; mul = mul + 1) begin: mul_muxes
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_mul_op1 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_mul[mul]            ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op1           ),
                .VLR        ( VLR                       ),
                .data_o     ( mul1[mul]                 )
            );
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_mul_op2 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_mul[mul]            ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op2           ),
                .VLR        ( VLR                       ),
                .data_o     ( mul2[mul]                 )
            );
        end
    endgenerate
    
    
    // Muxes DIVSs
    generate
        genvar div;
        for (div = 0; div < NUM_DIVS; div = div + 1) begin: div_muxes
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_div_op1 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_div[div]            ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op1           ),
                .VLR        ( VLR                       ),
                .data_o     ( div1[div]                 )
            );
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_div_op2 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_div[div]            ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op2           ),
                .VLR        ( VLR                       ),
                .data_o     ( div2[div]                 )
            );
        end
    endgenerate
    
    
    // Muxes SQRTSs (aqui solo hace falta uno)
    generate
        genvar sqrt;
        for (sqrt = 0; sqrt < NUM_SQRTS; sqrt = sqrt + 1) begin: sqrt_muxes
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_sqrt_op (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_sqrt[sqrt]          ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op2           ),
                .VLR        ( VLR                       ),
                .data_o     ( sqrt1[sqrt]               )
            );
        end
    endgenerate
    
    
    // Muxes operadores multifunción
    generate
        genvar logic_mux;
        for (logic_mux = 0; logic_mux < NUM_LOGICS; logic_mux = logic_mux + 1) begin: logic_muxes
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_logic_op1 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_logic[logic_mux]    ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op1           ),
                .VLR        ( VLR                       ),
                .data_o     ( logic1[logic_mux]         )
            );
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_logic_op2 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_logic[logic_mux]    ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op2           ),
                .VLR        ( VLR                       ),
                .data_o     ( logic2[logic_mux]         )
            );
        end
    endgenerate
    
    
    // Muxes ALUs float
    generate
        genvar alu_f_mux;
        for (alu_f_mux = 0; alu_f_mux < NUM_F_ALUS; alu_f_mux = alu_f_mux + 1) begin: alu_f_muxes
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_alu_f_op1 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_f_alu[alu_f_mux]    ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op1           ),
                .VLR        ( VLR                       ),
                .data_o     ( alu_f_1[alu_f_mux]        )
            );
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_alu_f_op2 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_f_alu[alu_f_mux]    ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op2           ),
                .VLR        ( VLR                       ),
                .data_o     ( alu_f_2[alu_f_mux]        )
            );
        end
    endgenerate
    
    
    // Muxes MULs float
    generate
        genvar mul_f_mux;
        for (mul_f_mux = 0; mul_f_mux < NUM_F_MULS; mul_f_mux = mul_f_mux + 1) begin: mul_f_muxes
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_mul_f_op1 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_f_mul[mul_f_mux]    ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op1           ),
                .VLR        ( VLR                       ),
                .data_o     ( mul_f_1[mul_f_mux]        )
            );
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_mul_f_op2 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_f_mul[mul_f_mux]    ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op2           ),
                .VLR        ( VLR                       ),
                .data_o     ( mul_f_2[mul_f_mux]        )
            );
        end
    endgenerate
    
    
    // Muxes DIVs float
    generate
        genvar div_f_mux;
        for (div_f_mux = 0; div_f_mux < NUM_F_DIVS; div_f_mux = div_f_mux + 1) begin: div_f_muxes
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_div_f_op1 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_f_div[div_f_mux]    ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op1           ),
                .VLR        ( VLR                       ),
                .data_o     ( div_f_1[div_f_mux]        )
            );
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_div_f_op2 (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_f_div[div_f_mux]    ),
                .data_i     ( reg_rd_o_g                ),
                .sel        ( alu_mux_sel_op2           ),
                .VLR        ( VLR                       ),
                .data_o     ( div_f_2[div_f_mux]        )
            );
        end
    endgenerate
    
    
    // Muxes SQRTs float
    generate
        genvar sqrt_f_mux;
        for (sqrt_f_mux = 0; sqrt_f_mux < NUM_F_SQRTS; sqrt_f_mux = sqrt_f_mux + 1) begin: sqrt_f_muxes
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
                .DATA_WIDTH ( DATA_WIDTH                ), 
                .VALID      ( VALID                     ),
                .MVL        ( MVL                       )
            ) mux_sqrt_f_op (
                .clk        ( clk                       ),
                .rst        ( rst                       ),
                .start      ( start_f_sqrt[sqrt_f_mux]  ),
                .data_i     ( reg_rd_o_g                ), 
                .sel        ( alu_mux_sel_op2           ),
                .VLR        ( VLR                       ),
                .data_o     ( sqrt_f_1[sqrt_f_mux]      )
            );
        end
    endgenerate
    
    
    // Mux para seleccionar dato a escribir en memoria (igual que todos los anteriores)
    mux_param #(
        .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS ), 
        .DATA_WIDTH ( DATA_WIDTH                ),
        .VALID      ( VALID                     ),
        .MVL        ( MVL                       )
    ) mux_ls (
        .clk        ( clk                       ),
        .rst        ( rst                       ),
        .start      ( mem_w_signal              ),  // Señal de seleccion: señal de escritura en memoria
        .data_i     ( reg_rd_o_g                ),  // Misma entrada de datos que los anteriores
        .sel        ( mem_mux_sel               ),  
        .VLR        ( VLR                       ),
        .data_o     ( mem_data_i                )   // La salida es la entrada de datos de la unidad load/store
    );
    
    
    // Mux/es para seleccionar los índices de acceso no regular a memoria (lectura, de nuevo funcionan casi igual que los anteriores)
   generate
        genvar mem_r;
        for (mem_r = 0; mem_r < MEM_READ_PORTS; mem_r = mem_r + 1) begin: mem_r_gen         
            mux_param #(
                .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS                              ), 
                .DATA_WIDTH ( B_ADDRESS                                              ),
                .VALID      ( VALID                                                  ),
                .MVL        ( MVL                                                    )
            ) indexed_read_mux (
                .clk        ( clk                                                    ),
                .rst        ( rst                                                    ),
                .start      ( mem_r_signal[mem_r] & indexed_signal                   ), // A parte de la señal lectura de memoria, también hace falta la señal "indexed"
                .data_i     ( indexed_mux_in                                         ),
                .sel        ( indexed_ld_sel                                         ),
                .VLR        ( VLR                                                    ),
                .data_o     ( index_load[mem_r*(B_ADDRESS+VALID) +: B_ADDRESS+VALID] )  // Escribe su salida en la posición correspondiente de "index_load"
            );
        end
    endgenerate
    
    
    // Mux para seleccionar los índices de acceso no regular a memoria (escritura, de nuevo funcionan casi igual que los anteriores)
    mux_param #(
        .NUM_INPUTS ( NUM_REGS * NUM_READ_PORTS     ), 
        .DATA_WIDTH ( B_ADDRESS                     ),
        .VALID      ( VALID                         ),
        .MVL        ( MVL                           )
    ) indexed_store_mux (
        .clk        ( clk                           ),
        .rst        ( rst                           ),
        .start      ( mem_w_signal & indexed_signal ),    // A parte de la señal de escritura de memoria, tambien hace falta la señal "indexed"
        .data_i     ( indexed_mux_in                ),
        .sel        ( indexed_st_sel                ),
        .VLR        ( VLR                           ),
        .data_o     ( index_store                   )     // Escribe su salida en index_store
    );
    
    // Instanciacion de la unidad load/store
    ls_unit #(
            .DEPTH          ( B_ADDRESS          ),     // Bits de profundidad de memoria
            .DATA_WIDTH     ( DATA_WIDTH         ),     // Tamaño del dato (32 bits)
            .VALID          ( VALID              ),     // Tamaño bit de valid
            .MVL            ( MVL                ),     // Tamaño máximo de vector
            .MAX_STRIDE     ( MAX_STRIDE         )      // Stride máximo 
    ) load_store (
            .clk            ( clk                ),     // Señal de reloj
            .rst            ( rst                ),     // Señal de reset
            .write_signal   ( mem_w_signal       ),     // Señal de escritura
            .read_signal    ( mem_r_signal       ),     // Señal de lectura (1 o 2 bits, un bit para cada puerto)
            .VLR            ( VLR                ),     // Tamaño de vector
            .address        ( addr               ),     // Entrada de direccion base
            .stride         ( stride_signal      ),     // Entrada de stride (1 o más)
            .indexed        ( indexed_signal     ),     // Señal de acceso no regular
            .index_load     ( index_load         ),     // Índice leído de registro vectorial para leer de memoria
                                                        // (anchura para uno o dos índices según el número de puertos
                                                        // de lectura de memoria)
            .index_store    ( index_store        ),     // Índice leído de registro vectorial para escribir memoria
            .data_in_store  ( mem_data_i         ),     // Dato entrante, leído de un registro, que se envia a memoria: registro -> load/store
            .data_in_load   ( mem_data_read_in   ),     // Dato entrante que ha sido leído de memoria: memoria -> load/store
            .mask           ( mask               ),     // Entrada de máscara (para las escrituras)
            .data_out_load  ( mem_data_o         ),     // Dato saliente leído de memoria, se envía hacia un registro: load/store -> registro
            .addr_read      ( addr_read          ),     // Dirección de lectura de memoria generada (ancho para 1 o 2 seguún nº de puertos)
            .data_out_store ( mem_data_write_out ),     // Dato saliente leído de un registro, se envía hacia memoria: load/store -> memoria
            .addr_write     ( addr_write         ),     // Direccion de escritura de memoria generada
            .busy_write     ( mem_busy_w         ),     // Señal de puerto de escritura de memoria ocupado
            .busy_read      ( mem_busy_r         )      // Señal de puerto/s de lectura de memoria ocupado/s (1 o 2 bits, segun nº puertos)
    );


    // Generate para instanciar todos los registros (NUM_REGS)    
    generate
        genvar k;
        for (k = 0; k < NUM_REGS; k = k+1) begin: regs_gen
            registro_dchinue #(
                .NUM_WRITE_PORTS   ( NUM_WRITE_PORTS          ),    // Número puertos de escritura
                .NUM_READ_PORTS    ( NUM_READ_PORTS           ),    // Numero puertos de lectura
                .DATA_WIDTH        ( DATA_WIDTH               ),    // Anchura del dato (32 bits)
                .VALID             ( VALID                    ),    // Tamaño bit de valid
                .MASK              ( MASK                     ),    // Tamaño bit de máscara
                .MVL               ( MVL                      ),    // Tamaño máximo de vector
                .ID                ( k                        )     // Identificador (para filtrar los prints y cosas así)
            ) reg_inst (
                .clk               ( clk                      ),    // Señal de reloj
                .rst               ( rst                      ),    // Señal de reset
                .VLR               ( VLR                      ),    // Tamaño del vector a usar
                .w_signal          ( reg_w_signal[k]          ),    // Señal de escritura (1 bit por puerto)
                .vid_masked_signal ( reg_masked_vid_signal[k] ),    // Señal de escritura vid (1 bit por puerto)
                .r_signal          ( reg_r_signal[k]          ),    // Señal de lectura (1 bit por puerto)
                .wd_i              ( reg_wd_i[k]              ),    // Dato entrante de escritura
                                                                    // anchura para tantos datos como puertos de escritura
                .rd_o              ( read_per_reg_o[k]        ),    // Dato saliente de lectura
                                                                    // anchura para tantos datos como puertos de lectura
                .busy_write        ( reg_w_busy[k]            ),    // Señal de puerto de escritura ocupado (1 bit por puerto)
                .busy_read         ( reg_r_busy[k]            ),    // Señal de puerto de lectura ocupado (1 bit por puerto)
                .first_elem        ( first_elem[k]            )     // Señal de primer elemento disponible
            );
        end
    endgenerate
    
    
    // Con los siguientes generates se instancian las unidades funcionales
    // De nuevo se detallan sólo las entradas y salidas de la primera
    // ya que el resto funcionan igual
    generate
        genvar alu_g;
        for (alu_g = 0; alu_g < NUM_MULS; alu_g = alu_g + 1) begin: alu_gen
            alu_aux #(
                .DATA_WIDTH ( DATA_WIDTH       ),   // Anchura del dato (32 bits)
                .MVL        ( MVL              ),   // Tamaño máximo de vector
                .SEGMENTS   ( SEGMENTS         ),   // Número de etapas en la segmentación simulada
                .ID         ( alu_g            )    // Identificador (para filtrar prints)
            ) alu_inst ( 
                .clk        ( clk              ),   // Señal de reloj
                .rst        ( rst              ),   // Señal de reset
                .start      ( start_alu[alu_g] ),   // Señal de inicio
                .cont_esc   ( control_esc      ),   // Señal del control escalar (la comparten todos, la captura el que recibe start)
                .op_esc     ( operand_esc      ),   // Operando escalar (lo comparten todos, lo captura el que recibe start)
                .mask       ( mask             ),   // Entrada de máscara (la comparten todos, la captura el que recibe start)
                .opcode     ( opcode           ),   // Código de operacion (0 suma, 1 resta)
                .VLR        ( VLR              ),   // Tamaño del vector a usar
                .arg1       ( alu1[alu_g]      ),   // Operando 1
                .arg2       ( alu2[alu_g]      ),   // Operando 2
                .out        ( alu_out[alu_g]   ),   // Resultado
                .busy       ( alu_busy[alu_g]  )    // Señal busy
            );
        end
    endgenerate
    
    generate
        genvar mul_g;
        for (mul_g = 0; mul_g < NUM_MULS; mul_g = mul_g + 1) begin: mul_gen
            mul_aux #(
                .DATA_WIDTH ( DATA_WIDTH       ),
                .MVL        ( MVL              ),
                .SEGMENTS   ( SEGMENTS         ),
                .ID         ( mul_g            )
            ) mul_inst ( 
                .clk        ( clk              ),
                .rst        ( rst              ),
                .start      ( start_mul[mul_g] ),
                .cont_esc   ( control_esc      ),
                .op_esc     ( operand_esc      ),
                .mask       ( mask             ),
                .VLR        ( VLR              ),
                .arg1       ( mul1[mul_g]      ),
                .arg2       ( mul2[mul_g]      ),
                .out        ( mul_out[mul_g]   ),
                .busy       ( mul_busy[mul_g]  )
            );
        end
    endgenerate
    
    generate
        genvar div_g;
        for (div_g = 0; div_g < NUM_DIVS; div_g = div_g + 1) begin: div_gen
            div_ipcore #(
                .DATA_WIDTH ( DATA_WIDTH       ),
                .MVL        ( MVL              )
            ) div_inst ( 
                .clk        ( clk              ),
                .rst        ( rst              ),
                .start      ( start_div[div_g] ),
                .op_div     ( op_div           ),
                .cont_esc   ( control_esc      ),
                .op_esc     ( operand_esc      ),
                .mask       ( mask             ),
                .VLR        ( VLR              ),
                .arg1       ( div1[div_g]      ),
                .arg2       ( div2[div_g]      ),
                .out        ( div_out[div_g]   ),
                .busy       ( div_busy[div_g]  )
            );
        end
    endgenerate
    
    generate
        genvar sqrt_g;
        for (sqrt_g = 0; sqrt_g < NUM_SQRTS; sqrt_g = sqrt_g + 1) begin: sqrt_gen
            sqrt_aux_i #(
                .DATA_WIDTH ( DATA_WIDTH         ),
                .MVL        ( MVL                )
            ) sqrt_inst ( 
                .clk        ( clk                ),
                .rst        ( rst                ),
                .start      ( start_sqrt[sqrt_g] ),
                .cont_esc   ( control_esc        ),
                .op_esc     ( operand_esc        ),
                .mask       ( mask               ),
                .VLR        ( VLR                ),
                .arg1       ( sqrt1[sqrt_g]      ),
                .out        ( sqrt_out[sqrt_g]   ),
                .busy       ( sqrt_busy[sqrt_g]  )
            );
        end
    endgenerate
    
    generate
        genvar logic_g;
        for (logic_g = 0; logic_g < NUM_LOGICS; logic_g = logic_g + 1) begin: logic_gen
            logic_aux #(
                .DATA_WIDTH    ( DATA_WIDTH           ),
                .MVL           ( MVL                  ),
                .NUM_LOGIC_OPS ( NUM_LOGIC_OPS        ),
                .SEGMENTS      ( SEGMENTS             ),
                .ID            ( logic_g              )
            ) logic_inst ( 
                .clk           ( clk                  ),
                .rst           ( rst                  ),
                .start         ( start_logic[logic_g] ),
                .float         ( float_signal         ),
                .sel_logic_op  ( sel_logic_op         ),
                .cont_esc      ( control_esc          ),
                .op_esc        ( operand_esc          ),
                .mask          ( mask                 ),
                .VLR           ( VLR                  ),
                .arg1          ( logic1[logic_g]      ),
                .arg2          ( logic2[logic_g]      ),
                .out           ( logic_out[logic_g]   ),
                .busy          ( logic_busy[logic_g]  )
            );
        end
    endgenerate
    
    generate
        genvar alu_f_g;
        for (alu_f_g = 0; alu_f_g < NUM_F_MULS; alu_f_g = alu_f_g + 1) begin: alu_f_gen
            ADD_SUB_SEG #(
                .DATA_WIDTH       ( DATA_WIDTH           ),
                .MVL              ( MVL                  ),
                .ID               ( alu_f_g              )
            ) alu_f_inst ( 
                .clk              ( clk                  ),
                .reset            ( rst                  ),
                .operand_a        ( alu_f_1[alu_f_g]     ),
                .operand_b        ( alu_f_2[alu_f_g]     ),
                .vlr_i            ( VLR                  ),
                .mask_i           ( mask                 ),
                .operation_code_i ( opcode               ),
                .cont_esc_i       ( control_esc          ),
                .op_esc_i         ( operand_esc          ),
                .start            ( start_f_alu[alu_f_g] ),
                .code_round       ( 2'b00                ),
                .final_result     ( alu_f_out[alu_f_g]   ),
                .busy             ( alu_f_busy[alu_f_g]  )
            );
        end
    endgenerate
    
    generate
        genvar mul_f_g;
        for (mul_f_g = 0; mul_f_g < NUM_F_MULS; mul_f_g = mul_f_g + 1) begin: mul_f_gen
            MULT_SEG #(
                .NPP          ( 24                   ),
                .BITS         ( 24                   ),
                .WIDTH        ( 48                   ),
                .DATA_WIDTH   ( DATA_WIDTH           ),
                .MVL          ( MVL                  ),
                .ID           ( mul_f_g              )
            ) mul_f_inst ( 
                .clk          ( clk                  ),
                .reset        ( rst                  ),
                .operand_a    ( mul_f_1[mul_f_g]     ),
                .operand_b    ( mul_f_2[mul_f_g]     ),
                .vlr_i        ( VLR                  ),
                .mask_i       ( mask                 ),
                .cont_esc_i   ( control_esc          ),
                .op_esc_i     ( operand_esc          ),
                .start        ( start_f_mul[mul_f_g] ),
                .code_round   ( 2'b01                ),
                .final_result ( mul_f_out[mul_f_g]   ),
                .busy         ( mul_f_busy[mul_f_g]  )
            );
        end
    endgenerate
    
    generate
        genvar div_f_g;
        for (div_f_g = 0; div_f_g < NUM_F_DIVS; div_f_g = div_f_g + 1) begin: div_f_gen
            DIV_SEG #(
                .DATA_WIDTH   ( DATA_WIDTH           ),
                .MVL          ( MVL                  ),
                .ID           ( div_f_g              )
            ) div_f_inst (
                .clk          ( clk                  ),
                .reset        ( rst                  ),
                .start        ( start_f_div[div_f_g] ),
                .operand_a    ( div_f_1[div_f_g]     ),
                .operand_b    ( div_f_2[div_f_g]     ),
                .vlr_i        ( VLR                  ),
                .mask_i       ( mask                 ),
                .cont_esc_i   ( control_esc          ),
                .op_esc_i     ( operand_esc          ),
                .final_result ( div_f_out[div_f_g]   ),
                .busy         ( div_f_busy[div_f_g]  )
            );
        end
    endgenerate
    
    generate
        genvar sqrt_f_g;
        for (sqrt_f_g = 0; sqrt_f_g < NUM_F_SQRTS; sqrt_f_g = sqrt_f_g + 1) begin: sqrt_f_gen
            sqrt_f_ipcore #(
                .DATA_WIDTH ( DATA_WIDTH             ),
                .MVL        ( MVL                    )
            ) sqrt_f_inst ( 
                .clk        ( clk                    ),
                .rst        ( rst                    ),
                .start      ( start_f_sqrt[sqrt_f_g] ),
                .cont_esc   ( control_esc            ),
                .op_esc     ( operand_esc            ),
                .mask       ( mask                   ),
                .VLR        ( VLR                    ),
                .arg1       ( sqrt_f_1[sqrt_f_g]     ),
                .out        ( sqrt_f_out[sqrt_f_g]   ),
                .busy       ( sqrt_f_busy[sqrt_f_g]  )
            );
        end
    endgenerate

    
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
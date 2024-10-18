`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.11.2023 12:13:38
// Design Name: 
// Module Name: fifo_queue
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


module fifo_queue #(parameter SIZE = 16, NUM_REGS=32, NUM_ESC_REGS = 32, DATA_WIDTH = 32, MVL=32, ADDRESS_WIDTH=10, MAX_STRIDE = 16) (
        // Entradas de control de la cola
        input clk,      // Señal de reloj
        input rst,      // Señal de reset
        input valid,    // Señal de valid
        
        // Señales de la instrucción decodificada
        input setvl,
        input add,
        input sub,
        input mul,
        input div,
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
		input strided,
		input float,
        input [1:0] esc,
        input masked_op,
        input load,
        input iload,
        input store,
        input istore,
        input [bitwidth(NUM_REGS)-1:0] src1,
        input [bitwidth(NUM_REGS)-1:0] src2,
        input [bitwidth(NUM_ESC_REGS)-1:0] src1_esc,
        input [bitwidth(NUM_ESC_REGS)-1:0] src2_esc,
        input [bitwidth(NUM_REGS)-1:0] dst,
        input [bitwidth(NUM_ESC_REGS)-1:0] dst_esc,
        input stalling,
        output setvl_o,
        output add_o,
        output sub_o,
        output mul_o,
        output div_o,
        output rem_o,
        output sqrt_o,
        output addmul_o,
        output peq_o,
		output pne_o,
		output plt_o,
		output sll_o,
		output srl_o,
		output sra_o,
		output log_xor_o,
		output log_or_o,
		output log_and_o,
		output sgnj_o,
		output sgnjn_o,
		output sgnjx_o,
		output pxor_o,
		output por_o,
		output pand_o,
		output vid_o,
		output vcpop_o,
		output strided_o,
		output float_o,
        output [1:0] esc_o,
        output masked_op_o,
        output load_o,
        output iload_o,
        output store_o,
        output istore_o,
        output [bitwidth(NUM_REGS)-1:0]     src1_o,
        output [bitwidth(NUM_REGS)-1:0]     src2_o,
        output [bitwidth(NUM_ESC_REGS)-1:0] src1_esc_o,
        output [bitwidth(NUM_ESC_REGS)-1:0] src2_esc_o,
        output [bitwidth(NUM_REGS)-1:0]     dst_o,
        output [bitwidth(NUM_ESC_REGS)-1:0] dst_esc_o,
        
        // Salidas de control de la cola FIFO
        output full,        //  Indica que la cola está llena
        output empty        //  Indica que la cola está vacía
    );
    
    
    // Parámetros orientativos para declarar la anchura de la memoria
    localparam num_ops = 29;                            // Número de operaciones
    localparam esc_conf = 2;                            // Bits para la configuración escalar
    localparam mask_conf = 1;                           // Bits para indicar uso de máscara
    localparam strided_conf = 1;                        // Bits para indicar acceso regular
    localparam float_conf = 1;                          // Bits para indicar operacion float
    localparam src1_w = bitwidth(NUM_REGS);             // Bits para el fuente 1 vectorial
    localparam src2_w = bitwidth(NUM_REGS);             // Bits para el fuente 2 vectorial
    localparam src1_esc_w = bitwidth(NUM_ESC_REGS);     // Bits para el fuente escalar 1
    localparam src2_esc_w = bitwidth(NUM_ESC_REGS);     // Bits para el fuente escalar 2
    localparam dst_w = bitwidth(NUM_REGS);              // Bits para el destino vectorial
    localparam dst_esc_w = bitwidth(NUM_ESC_REGS);      // Bits para el destino escalar
    localparam stride_w = bitwidth(MAX_STRIDE);         
    
    // Se suman todos los parametros para sacar el tamaño total de la memoria
    localparam total_width = dst_esc_w+dst_w+src2_esc_w+src1_esc_w+src2_w+src1_w+float_conf+strided_conf+mask_conf+esc_conf+num_ops;
    
    wire [total_width-1:0] salida_mem;                  // Salida de la memoria con los parámetros de la instruccion decodificada
    wire [total_width-1:0] entrada_mem;                 // Entrada de la memoria con los parámetros de la instruccion decodificada
    reg [bitwidth(SIZE)-1:0] write_index;               // Indice que apunta a la posición de la cola a escribir
    reg [bitwidth(SIZE)-1:0] read_index;                // Indice que apunta a la posición de la cola a leer
    reg [bitwidth(SIZE):0] count;                       // Contador de elementos dentro de la cola
    
    // Si la cola está vacía: no hay instrucciones guardadas por lo tanto la salida ha de ser 0, 
    // si no está vacía, copio el contenido de la salida de memoria sobre todos los
    // outputs (en el mismo orden en el que los he guardado anteriormente en la memoria, 
    // de tal forma que cada cosa está donde debería)
    assign {dst_esc_o, dst_o, src2_esc_o, src1_esc_o, src2_o, src1_o, 
            istore_o, store_o, iload_o, load_o, masked_op_o, esc_o, float_o, 
            strided_o, vcpop_o, vid_o, pand_o, por_o, pxor_o, sgnjx_o, sgnjn_o, sgnj_o, 
            log_and_o, log_or_o, log_xor_o, sra_o, srl_o, sll_o, plt_o, pne_o, 
            peq_o, addmul_o, sqrt_o, rem_o, div_o, mul_o, sub_o, add_o, setvl_o} = (empty) ? {total_width{1'b0}} : salida_mem;
            
            
    assign valid_o = ~empty;                                // Si la cola está vacía, los datos salientes no son válidos
    assign full = count == SIZE;                            // Si el contador llega al tamaño de la cola, está llena
    assign empty = (write_index == read_index) & ~full;     // Si los dos indices son iguales y la cola no está llena, entonces está vacía
    
    // Instanciación de la memoria de la cola
    fifo_mem #(
        .SIZE      ( SIZE                                           ),  // El tamaño de la cola (cuantas instrucciones decodificadas se pueden guardar)
        .WIDTH     ( total_width                                    )   // La suma del tamaño de todas las señales a almacenar
    ) queue (
        .clk_i     ( clk                                            ),  // Señal de reloj
        .rst       ( rst                                            ),  // Señal de reset
        .w_en      ( valid & ~full                                  ),  // Write enable -> mientras el dato entrante sea válido y la cola no esté llena se puede escribir
        .r_address ( read_index                                     ),  // Posición a leer, indicada por el indice de lectura
        .w_address ( write_index                                    ),  // Posición a escribir, indicada por el indice de escritura
        .w_data    ( {dst_esc, dst, src2_esc, src1_esc, src2, src1,
                      istore, store, iload, load,
                      masked_op, esc, float, strided, vcpop, vid, 
                      pand, por, pxor, sgnjx, sgnjn, sgnj, 
                      log_and, log_or, log_xor, sra, srl, sll, 
                      plt, pne, peq, addmul, sqrt, rem, div, mul, 
                      sub, add, setvl}                              ),  // La entrada de datos de la memoria, por donde se introducen todas las señales
                                                                        // de la instrucción decodificada recibida
        .r_output  ( salida_mem                                     )   // Instrucción decodificada que sale de la cola y que irá a la unidad de control
    );
    
    // La lógica usada para implementar la FIFO es la siguiente:
    // La salida es combinacional (no registrada), es decir, cambia en el instante en el que el puntero de lectura cambia
    // Las instrucciones SIEMPRE entran en la FIFO, aunque esté vacía y no haya parada en control
    // La lógica del contador es la siguiente: cuando la cola esté vacía y entre la primera instrucción,
    // el contador debe incrementar, ya que estamos ocupando un espacio de la FIFO (independientemente de que la instrucción se quede en stall o salga directamente),
    // a partir de ahí, las instrucciones que vayan llegando se irán almacenando en las posiciones consecutivas.
    // Si no hay parada, tanto el indice de escritura como de lectura irán incrementando para ir almacenando instrucciones decodificadas
    // en las siguientes posiciones e ir también leyendo. Mientras no haya parada y ambos índices incrementen, el contador de instrucciones no incrementa. 
    // Si hay parada, sólo incrementará el indice de escritura, por lo que iremos almacenando las instrucciones que llegan mientras estamos en parada,
    // en este caso sí que se incrementa el contador, porque estamos almacenando instrucciones sin enviar otras a ejecutar.
    // Si se llena la cola y aun se está en parada, se activa la señal full, que servirá para indicar que se debe parar la decodificación de instrucciones.
    // Cuando deje de haber parada, el puntero de lectura seguirá avanzando de ciclo en ciclo enviando instrucciones a ejecución
    
    // Cuando ya no lleguen más instrucciones, esto vendrá indicado por la entrada valid puesta a 0. Mientras esa entrada esté a 0, las señales entrantes
    // no serán almacenadas en la cola, por tanto la cola comenzará a vaciarse. Por tanto, el índice de escritura se mantendrá y el de lectura irá avanzando
    // Como estamos leyendo instrucciones sin almacenar nuevas el contador irá decrementanto. Si llega a 0, se activa la señal "empty" para indicar que la cola
    // está vacía, lo que hace que todas las señales pasen a valer 0, las cuales serán ignoradas por la unidad de control.
    
    
    // Bloque always que se encarga de controlar la lógica de los índices y el contador
    always @(posedge clk) begin
        // Señal de reset -> se reinician los indices y contadores
    	if (rst) begin
    		write_index <= 0;
    		read_index <= 0;
    		count <= 0;
    	end else if ((empty & valid & stalling) | (~empty & ~full & valid & stalling)) begin
            // Si la cola está vacía o tiene ya alguna instrucción (sin estar llena), valid está a 1 y hay parada.
            // Avanza el indice de escritura e incrementa el numero de elementos en la cola
            write_index <= write_index + 1;
            count <= count + 1;
        end else if ( empty & valid & ~stalling ) begin
            // Si la cola está vacía, la entrada es válida y no hay parada
            // (es lo mismo que antes prácticamente)
            write_index <= write_index + 1;
            count <= count + 1;
        end else if (~empty & ~valid & ~stalling) begin
            // Si la cola no está vacía, la entrada no es válida y no hay parada
            // Es decir, se está vaciando la cola
            // Avanza el indice de lectura y se decrementa el numero de elementos en la cola
            read_index <= read_index + 1;
            count <= count - 1;
        end else if (~empty & valid & ~stalling) begin
            // Si la cola no está vacía, la entrada es válida y no hay parada
            // Es decir: esta entrando a la vez una instrucción nueva y está saliendo otra
            // Avanzan los dos índices: lectura y escritura pero el numero de elementos en la cola no cambia
            write_index <= write_index + 1;
            read_index <= read_index + 1;
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

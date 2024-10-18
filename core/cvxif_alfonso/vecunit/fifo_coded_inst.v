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


module fifo_coded_inst #(parameter SIZE = 16, NUM_REGS=32, NUM_ESC_REGS = 32, DATA_WIDTH = 32, MVL=32, ADDRESS_WIDTH=10, MAX_STRIDE = 16) (
        input          clk,							//  entrada de reloj
        input          rst,
        input          valid, 						//  Asumo que el decodificador de instrucciones tiene una señal de valid (para indicar si se ha dejado o no de decodificar instrucciones) ME SIRVE COMO SEÑAL WRITE
        input   [31:0] instr_i,
        input          stalling,
        output  [31:0] instr_o,
        
        //output [bitwidth(MVL)-1:0] vector_length_reg_o,
        
        output full,      						    //  Indica que la FIFO está llena
        output empty  								//  Indica que la FIFO está vacía
    );
    
    wire [31:0] salida_mem; 			 			//  Salida de la memoria que contiene todos los parámetros de la función
    reg [bitwidth(SIZE)-1:0] write_index;  			//  Indice que apunta a la posición donde se va a escribir
    reg [bitwidth(SIZE)-1:0] read_index;  			//  Indice que apunta a la posición donde se va a leer
    reg [bitwidth(SIZE):0] count;  				    //  Contador de elementos dentro de la FIFO
    
    //  Si la cola está vacía: no hay instrucciones guardadas por lo tanto la salida ha de ser 0, si no está vacía, copio el contenido de la salida de memoria sobre todos los
    //  outputs (en el mismo orden en el que los he guardado anteriormente en la memoria, de tal forma que cada cosa está donde debería)
    assign instr_o = salida_mem;
    //assign entrada_mem = {vector_length_reg, stride, addr, dst, src_esc, src2, src1, store, load, masked_op, esc, cmp, mul, sub, add};
    assign valid_o = ~empty;  											//  Si la cola está vacía, lo que salga no es válido (la salida son 0s igualmente por lo que podría no ser necesario)
    assign full = count == SIZE;  										//  Si el contador llega al tamaño de la cola, está llena
    assign empty = (write_index == read_index) & ~full;  	//  Si los dos indices son iguales y la cola no está llena, entonces está vacía
    
    // Instanciación de la memoria encargada de almacenar las instrucciones
    fifo_mem #(
        .SIZE ( SIZE ),													//  El tamaño de la cola (cuantas instrucciones se pueden guardar)
        .WIDTH ( 32 )											//  El tamaño de los datos que almacena es el calculado a partir de todas las operaciones y elementos de configuración a guardar, es decir, el parámetro total_width
    ) queue (
        .clk_i ( clk ),												    //  Entrada de reloj
        .rst ( rst ),
        .w_en ( valid & ~full),											//  Write enable -> mientras el dato entrante sea válido y la cola no esté llena se puede escribir
        .r_address ( read_index ),										//  Posición a leer, indicada por el indice de lectura
        .w_address ( write_index ),										//  Posición a escribir, indicada por el indice de escritura
        .w_data ( instr_i ),		//  La información (instruccion) a escribir en la memoria, es la concatenacion de todas las entradas																																															// de la linea 90
        .r_output ( salida_mem )											//  Instrucción que sale de la cola y que irá a la unidad de control
    );
    
    //  La lógica usada para implementar la FIFO es la siguiente:
    //  La salida es combinacional (no registrada), es decir, cambia en el instante en el que el puntero de lectura cambia
    //  Las instrucciones SIEMPRE entran en la FIFO, aunque este vacía y no haya parada en control
    //  La lógica del contador es la siguiente: cuando la cola esté vacía y entre la primera instrucción,
    //  el contador debe incrementar, ya que estamos ocupando un espacio de la FIFO (aunque la instrucción se quede en stall o salga directamente),
    //  a partir de ahí, las instrucciones que vayan llegando se almacenarán si stall está a 1 (la instrucción apuntada por el indice de lectura está esperando 
    //  ya que hay dependencias en control) por lo que el puntero de escritura irá avanzando y el puntero de lectura
    //  se quedará parado
    //  Cuando deje de haber un stall, el puntero de lectura seguirá avanzando de ciclo en ciclo enviando instrucciones a ejecución
    //  hasta que llegue una nueva parada o se vacíe la cola
    
    
    // Bloque always que se encarga de controlar la lógica de los índices y el contador
    always @(posedge clk) begin
    	if (rst ) begin
    		write_index <= 0;
    		read_index <= 0;
    		count <= 0;
    	end else if ((empty & valid & stalling) | (~empty & valid & stalling)) begin
        //  Si la cola está vacía o tiene alguna instrucción, pero el valid está a 1 y hay parada, 
        //  Es decir: con cola vacia o no, llegando una nueva instrucción y con parada, la instrucción nueva se almacena
        //  y aumenta el numero de instrucciones almacenadas
        //  Avanza el indice de escritura e incrementa el numero de elementos en la cola
            write_index <= write_index + 1;
            count <= count + 1;
        end else if ( empty & valid & ~stalling ) begin
        //  Si la cola está vacía, la entrada es válida y no hay parada
        //  Es decir: con cola vacía, llegando una nueva instrucción y sin parada, la instrucción nueva (que es la primera)
        //  se almacena, ya que aunque haga bypass y vaya directamente a control, cuenta como si estuviera dentro de la cola
        //  Avanza el indice de escritura e incrementa el numero de elementos en la cola
            write_index <= write_index + 1;
            count <= count + 1;
        end else if (~empty & ~valid & ~stalling) begin
        //  Si la cola no está vacía, la entrada no es válida y no hay parada
        //  Es decir, no me llegan instrucciones nuevas y no hay parada, por lo que sale una nueva instrucción de la cola,
        //  haciendo que ahora haya una instrucción menos almacenada 
        //  Avanza el indice de lectura y se decrementa el numero de elementos en la cola
            read_index <= read_index + 1;
            count <= count - 1;
        end else if (~empty & valid & ~stalling) begin
        //  Si la cola no está vacía, la entrada es válida y no hay parada
        //  Es decir: esta entrando a la vez una instrucción nueva y está saliendo otra
        //  Avanzan los dos índices: lectura y escritura pero el numero de elementos en la cola no cambia
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

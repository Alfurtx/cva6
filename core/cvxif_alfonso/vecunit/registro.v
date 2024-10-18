`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.09.2023 13:34:27
// Design Name: 
// Module Name: registro_mem
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

/* (* KEEP = "{TRUE|FALSE|SOFT}" *) */
module registro_dchinue #(parameter NUM_WRITE_PORTS = 1, NUM_READ_PORTS = 2, DATA_WIDTH = 32, VALID = 1, MASK = 1, MVL = 64, ID = 0) (
    input  clk,                                                      // Señal de reloj
    input  rst,                                                      // Señal de reset
    input  [bitwidth(MVL):0]     VLR,                                // Entrada para recibir el VLR
    input  [NUM_WRITE_PORTS-1:0] w_signal,                           // Señal de escritura, un bit por cada puerto de escritura: cuando se pone a uno indica que se va a escribir por ese puerto
    input  [NUM_WRITE_PORTS-1:0] vid_masked_signal,                  // Señal que indica escritura tipo vid en un puerto de escritura, un bit por cada puerto de escritura
    input  [NUM_READ_PORTS-1:0]  r_signal,                           // Señal de lectura, un bit por cada puerto de lectura: cuando se pone a uno indica que se va a leer por ese puerto
    input  [(NUM_WRITE_PORTS*(DATA_WIDTH+VALID+MASK))-1:0] wd_i,     // Entrada de los datos de todos los puertos de escritura: bus con anchura de (bit valid + bit máscara + datos) * numero de puertos escritura
    output [(NUM_READ_PORTS*(DATA_WIDTH+VALID))-1:0]       rd_o,     // Salida de los datos a leer del registro: bus con anchura de (bit valid + datos) * numero de puertos lectura
    output [NUM_WRITE_PORTS-1:0] busy_write,                         // Salida para indicar puertos de escritura ocupados: un bit por puerto de escritura - 1: ocupado 0: libre
    output [NUM_READ_PORTS-1:0]  busy_read,                          // Salida para indicar puertos de lectura ocupados: un bit por cada puerto de lectura - 1: ocupado 0: libre
    output first_elem                                                // Salida para indicar primer elemento disponible
    );
    localparam valid_pos_w = DATA_WIDTH+VALID;                       // Posición de bit valid (esto es en los casos que hay bit de máscara: todo dato que viaje hacia un registro para ser escrito)
    localparam mask_pos_w  = DATA_WIDTH;                             // Posición de bit mask (primer bit despues de los datos)
    localparam input_width = DATA_WIDTH + MASK + VALID;              // Anchura dato + bits de control
    
    
    
    
    reg [DATA_WIDTH-1:0] vector[0:MVL-1];                            // Registro que almacena un vector, máximo de MVL elementos de tamaño DATA_WIDTH
    
    // Los puertos pueden estar siendo usados simultáneamente en instrucciones diferentes, se almacena el VLR de cada puerto por separado
    reg [bitwidth(MVL):0] vlr_w[0:NUM_WRITE_PORTS-1];                // Registro para almacenar el vlr de cada puerto de escritura
    reg [bitwidth(MVL):0] vlr_r[0:NUM_READ_PORTS-1];                 // Registro para almacenar el vlr de cada puerto de lectura
    
    // Contador para controlar posición a leer/escribir (y elementos procesados) -- contador == vlr la instrucción ha terminado (asumo que siempre uso vectores desde la posicion 0 en adelante)
    reg [bitwidth(MVL):0] counter_w	[0:NUM_WRITE_PORTS-1];           // Almacena el contador de cada puerto de escritura
    reg [bitwidth(MVL):0] counter_vid	[0:NUM_WRITE_PORTS-1];       // Almacena el contador de cada puerto de escritura (escritura vid)
    reg [bitwidth(MVL):0] counter_r   [0:NUM_READ_PORTS-1];          // Almacena el contador de cada puerto de lectura
    
    // Estos registros son los que generan las salidas para busy_write y busy_read (no sabia en su momento que podia declarar los outputs como registros directamente asi que están aquí a parte)
    // en los bucles de control más adelante se entiende mejor como funcionan
    reg [NUM_WRITE_PORTS-1:0] busy_write_reg;                        // Almacena el estado de cada puerto de escritura
    reg [NUM_WRITE_PORTS-1:0] vid_masked_reg;                        // Almacena señal de escritura vid de cada puerto de escritura
                                                                     // El comportamiento de la escritura vid se explica más adelante
    reg [NUM_READ_PORTS-1:0]  busy_read_reg;                         // Almacena el estado de cada puerto de lectura
    
    // Este wire sirve para tomar la entrada wd_i y separarla en las entradas correspondientes a cada puerto de escritura (asi se manipula más cómodamente)
    wire [DATA_WIDTH+VALID+MASK-1:0] data [0:NUM_WRITE_PORTS-1];
    
    wire [NUM_WRITE_PORTS-1:0] first_elem_available;                 // Un bit por puerto de escritura, indica si el primer elemento del vector ya ha sido escrito
                                                                     // (si el puerto no está escribiendo también se pone a 1)
                                                                     // si todos estan a 1 la salida first_elem = 1
                                                                     
                                                                     
      
      
    // Este generate se encarga de tomar la salida que sería de cada uno de los puertos de lectura y situarla en su respectiva posición en el buffer rd_o
    // Si tengo 2 puertos de lectura y por cada puerto saco 1 bit de valid + un dato de 32 bits, el buffer será de tamaño 66 ( [65:0] ), el primer puerto de lectura ocupará
    // desde 0 hasta 32 y el segundo desde 33 hasta 65. El bucle se encarga situar los datos en esas posiciones.
    // Si el puerto está busy, el valid saldrá con valor 1, si no, saldrá con valor 0 para indicar que el dato que está saliendo no es válido y debe ser ignorado
    // Tambien asigna a la salida busy_read el estado de cada puerto de lectura: ocupado o libre (lo dicho antes, podría haber hecho directamente que las salidas busy estuvieran registradas)
    
    generate
        genvar i;
        for (i = 0; i < NUM_READ_PORTS; i = i+1) begin: Gen_Assign_Read
            assign rd_o[(i * (DATA_WIDTH+VALID)) +: (DATA_WIDTH+VALID)] = (busy_read_reg[i] & (vlr_r[i] > 0)) ? {1'b1, vector[(counter_r[i]-1'b1)]} : {1'b0, 32'b0};
            assign busy_read[i] = busy_read_reg[i];
        end
    endgenerate

    
    // Este generate assigna a busy_write el estado de cada puerto de escritura: ocupado o libre (igual que la linea 74 de antes pero para los puertos de escritura en vez de los de lectura)
    generate
        genvar r;
        for (r=0; r < NUM_WRITE_PORTS; r = r+1) begin: Gen_Assign_Write
            assign busy_write[r] = busy_write_reg[r];
        end
    endgenerate
    
    
    // Este generate controla las señales de vlr, busy, counter, counter_vid y señal vid de cada puerto de escritura
    // Usando la genvar o se crea un bloque always para cada puerto
    // Señal rst reinicia todos los registros
    // Si recibo señal de escritura y vlr recibido > 0 -> capturo vlr, pongo busy = 1, inicio contador a 1, inicio contador_vid a 0, capturo señal vid_masked
    // En cada ciclo, si busy = 1, el dato entrante a escribir es válido
    // Si recibo ciclo de reloj y se cumple que: estoy ocupado (busy=1), el dato que me llega por la entrada es válido (el elemento en la posición valid_pos_w, que es el bit de valid, está a 1)
    // y el contador es menor o igual al vlr que me he guardado anteriormente (realmente nunca va debería llegar a ser mayor pero lo compruebo por si acaso) hago lo siguiente:
    // Si el contador es igual al vlr estoy en el último elemento -> se acaba la instrucción -> debo resetear el contador y el vlr a 0 y poner el busy a 0 (así indico que ese puerto vuelve a estar disponible)
    generate
      genvar o;
      for (o = 0; o < NUM_WRITE_PORTS; o = o+1) begin: vlr_assignments_write
        always @(posedge clk) begin
          if (rst) begin                                                                                // Señal de reinicio
            vlr_w[o] <= 0;                                                                                  // vlr a 0
            busy_write_reg[o] <= 0;                                                                         // busy a 0
            counter_w[o] <= 0;                                                                              // counter a 0
            counter_vid[o] <= 0;                                                                            // counter_vid a 0
            vid_masked_reg[o] <= 0;                                                                         // registro señal vid a 0
          end else if (w_signal[o] & (VLR > 0)) begin                                                   // Señal de escritura y vlr > 0
            vlr_w[o] <= VLR;                                                                                // Capturo vlr actual
            busy_write_reg[o] <= 1'b1;                                                                      // Pongo busy = 1
            counter_w[o] <= 1;                                                                              // Inicio contador a 1
            counter_vid[o] <= 0;                                                                            // Inicio contador_vid a 0
            vid_masked_reg[o] <= vid_masked_signal[o];                                                      // Capturo señal escritura_vid
          end else if (busy_write_reg[o] & data[o][valid_pos_w] & (counter_w[o] <= vlr_w[o])) begin     // Si ocupado & dato entrante es válido & contador menor o igual que vlr
            if (counter_w[o] == vlr_w[o]) begin                                                             // Si contador == vlr -> operacion terminada
              counter_w[o] <= 0;                                                                            // Reiniciar contador
              counter_vid[o] <= 0;                                                                          // Reiniciar contador_vid
              busy_write_reg[o] <= 1'b0;                                                                    // Desactivar busy
              vlr_w[o] <= 0;                                                                                // Reiniciar vlr
              vid_masked_reg[o] <= 0;                                                                       // Reiniciar señal vid capturada
            end else if (counter_w[o] < vlr_w[o])                                                       // Si contador < vlr -> operación en curso
              counter_w[o] <= counter_w[o] + 1'b1;                                                          // Incrementar contador
              if(vid_masked_reg[o] & data[o][mask_pos_w]) begin                                             // Si escritura tipo vid & bit de máscara del dato entrante = 1
                counter_vid[o] <= counter_vid[o] + 1;                                                           // Incrementar contador vid
            end
          end
        end    
      end
    endgenerate
    
    // Este generate se encarga de implementar el funcionamiento del wire data que he mencionado en la linea 58-59
    // Si tengo dos puertos de escritura y por cada puerto entra: bit de valid + bit de máscara + dato de 32 bits, tendré un bus de 68 bits ( [67:0 ] )
    // El primer puerto corresponderá a los bits desde el 0 al 33 y el segundo puerto del 34 al 67
    // Este generate guarda los bits del 0 al 33 en data[0], y los bits del 34 al 67 en data[1]
    generate
        genvar o2;
        for (o2 = 0; o2 < NUM_WRITE_PORTS; o2 = o2+1) begin: wire_write
            assign data[o2] = wd_i[(o2+1) * (DATA_WIDTH+VALID+MASK) - 1 : o2 * (DATA_WIDTH + VALID + MASK)];
        end
    endgenerate
    
    
    // Este generate se encarga de indicar para cada puerto de escritura si el primer elemento del vector ya está disponible para leer, es decir: si está busy pero el
    // primer elemento ya está escrito, o si no está busy por lo que no genera problema
    // (0 quiere decir que no esta disponible, 1 quiere decir que si que está disponible)
    // Esto se guarda en cada una de las posiciones del first_elem_available:
    // first_elem_available[0] indica si el puerto de escritura 0 ya ha escrito (si está escribiendo) el primer elemento del vector
    // first_elem_available[1] indica si el puerto de escritura 1 ya ha escrito (si está escribiendo) el primer elemento del vector
    // ...
    generate
        genvar fe;
        for (fe = 0; fe < NUM_WRITE_PORTS; fe = fe + 1) begin: first_elem_gen
            assign first_elem_available[fe] = (busy_write_reg[fe] & counter_w[fe] > 1 & ~vid_masked_reg[fe]) | ~busy_write_reg[fe];
        end
    endgenerate
    
    // Ahora simplemente se hace & de todos los bits de first_elem_available poniendo el resultado en first_elem,
    // si en algun puerto el primer elemento no está disponible, first elem valdrá 0
    // por lo que la instrucción que venga detrás, si tiene que leerlo, esperará
    assign first_elem = &first_elem_available;
   
    
    
    // Bloque generate para elegir, para cada puerto de escritura, qué índice usar
    // Si la escritura no es vid, usaré el contador normal como índice
    // Escribiré en la posición indicada por el contador - 1
    // Si la escritura es vid, usaré el contador vid como índice
    // Escribiré en la posición indicada por el contador vid
    
    wire [bitwidth(MVL):0] index_write [0:NUM_WRITE_PORTS-1];
    
    generate
        genvar index_w;
        for(index_w = 0; index_w < NUM_WRITE_PORTS; index_w = index_w + 1) begin : assign_index_w
            assign index_write[index_w] = (vid_masked_reg[index_w]) ? counter_vid[index_w] : counter_w[index_w]-1'b1;
        end
    endgenerate
    
    
    // Como tengo un bloque always para cada puerto de escritura y no se puede escribir sobre un mismo registro desde distintos bloques always
    // Uso este bloque que itera a través de los puertos de escritura y va escribiendo en orden secuencial
    // Para cada puerto de escritura "k" compruebo que: el puerto esté busy, el valid esté a 1, la máscara esté a 1 y el vlr > 0
    // La diferencia entre la máscara y el valid es que, si el valid = 0 quiere decir que debo ignorar el dato y no incrementar el contador, 
    // pero si la máscara = 0 (y valid = 1) el dato ES válido pero no debo escribir el resultado pero sí incrementar el contador
    // Para saber sobre qué posición escribir se usa el índice index_write de la linea 169, que tiene en cuenta el tipo de escritura que se hace vid o normal
    // Escritura normal:
    // Indexo la posición a escribir con el contador normal. Cuando recibo un dato con el bit de máscara a 0, no escribo y
    // el contador incrementa -> la posición que tenía el bit de máscara a 0 se ignora
    // Escritura vid:
    // Indexo la posición a escribir con el contador vid. Cuando recibo un dato con el bit de máscara a 0, no escribo
    // pero el contador vid no incrementa (el contador normal incrementa igualmente) -> la posición que tenía el bit
    // de máscara a 0 no es ignorada, se espera hasta recibir un dato con el bit de máscara a 1 para escribirla
    // De esta forma, todos los datos con bit de máscara a 1 se escriben en posiciones consecutivas
    // (útil para la ejecución condicional basada en índices descrita en la memoria del TFG)
    
    integer k;
    integer rst_reg;
    
    always @(posedge clk)
    begin
    	if (rst) begin
    		for (rst_reg = 0; rst_reg < MVL ; rst_reg = rst_reg + 1) begin
    			vector[rst_reg] <= 0;
    		end
    	end else begin
			for (k = 0; k < NUM_WRITE_PORTS; k = k+1) begin
				if (busy_write_reg[k] & data[k][valid_pos_w] & data[k][mask_pos_w] & (vlr_w[k] > 0)) begin
					   vector[index_write[k]] <= data[k][DATA_WIDTH-1:0];
				end
			end
		end
    end
    

        
    // Este generate hace exactamente lo mismo que en la escritura, pero para la lectura
    // La diferencia es que ahora no hace falta mirar el puerto de entrada, ya que estamos leyendo
    // Por lo que sólo se gestionan: vlr, busy y counter (no hay counter vid ni señal vid)
    // Se comienza a hacer la lectura -> se cuentan tantos ciclos como el vlr que hayamos recibido -> la lectura termina
    // En las lineas 76-77 es donde se usan estas señales para contolar los elementos que se leen
    generate
        genvar h;
        for (h = 0; h < NUM_READ_PORTS; h = h+1) begin: prepare_read_ports
            always @(posedge clk) begin
            	if (rst) begin
            		vlr_r[h] <= 0;
            		busy_read_reg[h] <= 0;
            		counter_r[h] <= 0;
            	end else if (r_signal[h] & (VLR > 0)) begin
                    vlr_r[h] <= VLR;
                    busy_read_reg[h] <= 1'b1;
                    counter_r[h] <= 1; //
                end else if (busy_read_reg[h] & (counter_r[h] <= vlr_r[h])) begin
                    if (counter_r[h] == vlr_r[h]) begin
                        counter_r[h] <= 0; //
                        busy_read_reg[h] <= 1'b0;
                        vlr_r[h] <= 0;
                    end else if (counter_r[h] < vlr_r[h])
                        counter_r[h] <= counter_r[h] + 1'b1; 
                end
            end
        end
    endgenerate
    
    
    // synthesis translate_on
  	
  	// Bloque always para contar ciclos
    reg [15:0] tics;
    always @(posedge clk) begin
    	if (rst) begin
    		tics <= 0;
    	end else begin
    		tics <= tics + 1;
    	end
    end
    
    // Bloque always para hacer display de las escrituras en los registros (se puede cambiar el ID para ver las escrituas de unos u otros)
    
    generate
        genvar w_pr;
        for (w_pr = 0; w_pr < NUM_WRITE_PORTS; w_pr = w_pr + 1) begin: print_write_generate
            always @(posedge clk)
                if (busy_write_reg[w_pr] & data[w_pr][32] & ID == 3) begin
                    $display ("Escritura registro\t %d : puerto %d : posición %d : escrito = %d : ciclo %d", ID, w_pr, counter_w[w_pr]-1'b1, data[w_pr][DATA_WIDTH-1:0], tics+1'b1);
                end
        end
    endgenerate
        
    // Bloque always para hacer display de las lecturas en los registros (tambien se puede cambiar el ID)
    generate
        genvar r_pr;
        for (r_pr = 0; r_pr < NUM_READ_PORTS; r_pr = r_pr + 1) begin: print_read_generate
            always @(posedge clk) begin
                if (busy_read_reg[r_pr]) begin
                    $display ("Lectura registro\t %d : puerto %d : posición %d : leido =\t %d : ciclo %d", ID, r_pr, counter_r[r_pr], vector[counter_r[r_pr]], tics);
                end
            end
        end
    
    endgenerate
    
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

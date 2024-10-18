`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.10.2023 12:00:08
// Design Name: 
// Module Name: ls_unit
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

// El parametro MEM_READ_PORTS SÓLO se puede cambiar entre 1 y 2

module ls_unit #(

    parameter DEPTH = 10, 
    parameter MEM_READ_PORTS = 2, 
    parameter DATA_WIDTH = 32, 
    parameter VALID = 1, 
    parameter MASK = 1, 
    parameter MVL = 64, 
    parameter MAX_STRIDE = 16
  ) (
    input clk,                                                              // Señal de reloj
    input rst,															    // Señal de reset
    input write_signal,                                                   	// Señal de escritura
    input [MEM_READ_PORTS-1:0] read_signal,                                 // Señal de lectura (un bit por puerto, puede haber 1 o 2)
    input [bitwidth(MVL):0] VLR,                                 			// Entrada para recibir el VLR
    input [DEPTH-1:0] address,												// Entrada de la dirección base para generar el resto de direcciones
    input [bitwidth(MAX_STRIDE)-1:0] stride,                 			    // Entrada para el stride entre las direcciones de memoria (se usa si se hacen accesos regulares -> indexes = 0)
    input indexed,                                                          // Señal que indica si se hacen accesos regulares o no -> 0 = Regular / 1 = No regular (usar indices)
    input [DEPTH+VALID-1:0] index_store,                                    // Entrada para ir recibiendo índices para la escritura
                                                                            // Bus con anchura de (bits de profundidad de memoria + valid)
    input [((DEPTH+VALID)*MEM_READ_PORTS)-1:0] index_load,                  // Entrada para ir recibiendo índices para la lectura
                                                                            // Bus con anchura de (bits de profundidad de memoria + valid) * numero de puertos de lectura
                                                                            
                                                                            // Realmente los índices leídos serán de 32 bits, pero como sólo podemos usar tantos bits
                                                                            // como profundidad tenga la memoria, la parte alta no se usará nunca, por lo que limitamos
                                                                            // el tamaño de los puertos para simplificar.
    input [DATA_WIDTH+VALID-1:0] data_in_store,          		            // Entrada del dato a escribir en la memoria, leido de un registro vectorial
    input [(DATA_WIDTH*MEM_READ_PORTS)-1:0] data_in_load,                   // Entrada del dato leído de memoria a enviar hacia los registros vectoriales
    input [MVL-1:0] mask,                                                   // Entrada para la máscara
    output [((DATA_WIDTH+MASK+VALID)*MEM_READ_PORTS)-1:0]  data_out_load,	// Salida del dato leido de memoria a enviar hacia los registros vectoriales
    output [(DEPTH*MEM_READ_PORTS)-1:0] addr_read,                          // Dirección de lectura de memoria generada
                                                                            // Bus de tamaño (profundidad de memoria * num puertos de lectura de memoria)
    output [DATA_WIDTH+VALID+MASK-1:0] data_out_store,			            // Salida del dato a escribir en memoria, leído de un registro vectorial
    output [DEPTH-1:0] addr_write,                                          // Dirección de escritura generada
                                                                            // Bus de tamaño profundidad de memoria
    output busy_write,                                                      // Señal puerto de escritura ocupado
    output [MEM_READ_PORTS-1:0] busy_read                                   // Señal puerto de lectura ocupado (1 bit por puerto de lectura)
  );
    
    
    
    
    // Como los puertos pueden estar funcionando de forma simultanea, guardo el vlr para cada uno
    reg [bitwidth(MVL):0] vlr_write;                                    // Registro para almacenar vlr en escritura
    reg [bitwidth(MVL):0] vlr_read [MEM_READ_PORTS-1:0];                // Registro para alamcenar vlr en lectura (1 o 2 posiciones segun MEM_READ_PORTS)
    reg [bitwidth(MVL):0] counter_write;                                // Contador de elementos procesados en escritura
    reg [bitwidth(MVL):0] counter_read [MEM_READ_PORTS-1:0];            // Contador de elementos procesados en lectura (1 o 2 posiciones segun MEM_READ_PORTS)
    reg [DEPTH-1:0] addr_write_reg;                                     // Registro para almacenar direccion base/direcciones generadas de escritura
    reg [DEPTH-1:0] addr_read_reg[MEM_READ_PORTS-1:0];                  // Registro para almacenar direccion base/direcciones generadas de lectura (1 o 2 posiciones segun MEM_READ_PORTS)
    reg [MEM_READ_PORTS-1:0] busy_read_reg;                             // Registro para indicar puerto de lectura ocupado (1 bit por puerto)
    reg busy_write_reg;                                                 // Registro para indicar puerto de escritura ocupado
   
    reg [bitwidth(MAX_STRIDE)-1:0] stride_r_reg[MEM_READ_PORTS-1:0];    // Registro para almacenar stride de lectura en acceso regular (1 o 2 posiciones segun MEM_READ_PORTS)
    reg [bitwidth(MAX_STRIDE)-1:0] stride_w_reg;                      	// Registro para indicar el stride en la dirección durante una operacion de escritura
   
    reg indexed_store_reg;                                              // Registro para almacenar señal de acceso regular o no para escritura
    reg [MEM_READ_PORTS-1:0] indexed_load_reg;                          // Registro para almacenar señal de acceso regular o no para lectura
   
    reg [MVL-1:0] mask_reg_write;                                       // Registro para almacenar la máscara de escritura
    reg [MVL-1:0] mask_reg_read [0:MEM_READ_PORTS-1];                   // Registro para alamcenar la/s máscara/s de lectura
    
    
    // Generate para montar:
    // Salida data_out_load -> envío de datos leídos de memoria hacia los registros vectoriales -> resumen: reenviar data_in_load hacia data_out_load
    // Salida addr_read -> salida de direccion de lectura de memoria generada (hacia memoria)
    // Explicacion idéntica a las lineas 72 y 73 del archivo de los registros vectoriales (o tambien 137 y 138) es una lógica que se repite mucho a lo largo del trabajo
    generate
        genvar read_o;
        for (read_o = 0; read_o < MEM_READ_PORTS; read_o = read_o + 1) begin: assign_read_outs
            assign data_out_load[read_o * (DATA_WIDTH+VALID+MASK) +: DATA_WIDTH+VALID+MASK] = 
                   (busy_read_reg[read_o]) ? {1'b1, mask_reg_read[read_o][counter_read[read_o]-1'b1],
                                              data_in_load[read_o * DATA_WIDTH +: DATA_WIDTH]} :          // Si puerto de lectura busy, los datos salen con bit de valid y máscara activos
                                             {2'b00, data_in_load[read_o * DATA_WIDTH +: DATA_WIDTH]};    // Si puerto de lectura no busy, los datos salen con bits valid y máscara inactivos
            
            // Si estamos haciendo accesos no regulares, la dirección nueva se genera a partir de la base (almacenada en addr_read_reg) y el índice recibido
            // Si son accesos no regulares, la dirección nueva es la que haya en addr_read_reg (que se irá incrementando ciclo a ciclo con el stride)
            assign addr_read[(read_o * DEPTH) +: DEPTH] = (indexed_load_reg[read_o]) ? 
                                                        addr_read_reg[read_o] + index_load[read_o * (DEPTH+VALID) +: DEPTH+VALID] :
                                                        addr_read_reg[read_o];
        end
    endgenerate
    
    // Igual que arriba pero para la escritura, como hay un sólo puerto siempre, no hace falta generate
    // Salida data_out_store -> envío de datos leídos de un registro vectorial hacia la memoria -> resumen: reenviar data_in_store hacia data_out_store
    // Salida addr_write -> salida de direccion de escritura de memoria generada (hacia memoria)
    // Si puerto de escritura busy, bit valid a 1 y el bit máscara se indexa con el contador y la máscara recibida (falta implementar esto en la lectura)
    assign data_out_store = (busy_write) ? {data_in_store[DATA_WIDTH], mask_reg_write[counter_write-1'b1], data_in_store[DATA_WIDTH-1:0]} : 34'b0;
    assign addr_write = (indexed_store_reg) ? addr_write_reg + index_store : addr_write_reg;
    
    // Control similar a los registros vectoriales
    // Este always controla busy, vlr, counter, dirección, stride, indexed y máscara para la escritura
    // Señal de reset se reinician todos esos registros
    // Señal de escritura se captura: vlr, direccion base, stride, indexed (para saber el tipo de acceso regular o no regular) y máscara.
    // Se inicia contador y se pone busy activo
    // Mientras el puerto de escritura esté ocupado y el dato entrante sea válido (bit valid en posición 33, ya que en este dato entrante no hay bit de máscara) en cada ciclo:
    // Si contador == vlr, operacion terminada, se reinician los registros y busy se pone a 0
    // Si contador < vlr, operacion en curso:
    // En el caso de acceso no regular -> indexed_store_reg == 1; comprobar si el índice entrante (leído de un registro vectorial) es valid
    // (en estos el bit de valid está en la posición DEPTH, ya que el tamaño en bits del índice es [DEPTH-1:0],
    // asi evitamos usar buses de 32 bits en los que se usarían sólo los DEPTH primeros bits). Si índice valido -> incrementamos contador
    // En el caso de acceso regular -> indexed_store_reg == 1; incrementar dirección base usando el stride e incrementar contador.
    always @(posedge clk)
    begin
    	if (rst) begin            // Señal reset reiniciar registros
    		busy_write_reg <= 0;
    		vlr_write <= 0;
    		counter_write <= 0;
    		addr_write_reg <= 0;
    		stride_w_reg <= 0;
    		indexed_store_reg <= 0;
    		mask_reg_write <= 0;
    	end else if (write_signal) begin      // Señal escritura capturar entradas, iniciar contador y busy a 1
            busy_write_reg <= 1'b1;
            vlr_write <= VLR;
            counter_write <= 1;
            addr_write_reg <= address;
            stride_w_reg <= stride;
            indexed_store_reg <= indexed;
            mask_reg_write <= mask;
        end else if (busy_write_reg && data_in_store[DATA_WIDTH]) begin   // Puerto ocupado y dato entrante válido
            if (counter_write == vlr_write) begin                         // Si contador == vlr, terminar operacion
                counter_write <= 0;
                busy_write_reg <= 1'b0;
                stride_w_reg <= 0;
                indexed_store_reg <= 0;
            end else begin                                                // Si contador < vlr, continuar operacion
            	if (indexed_store_reg & index_store[DEPTH]) begin         // Acceso no regular -> compruebo índice e incremento contador
            		counter_write <= counter_write + 1;
            	end else if (~indexed_store_reg) begin                    // Acceso regular -> incremento direccion y contador
                addr_write_reg <= addr_write_reg + stride_w_reg;
                counter_write <= counter_write + 1;
            	end
            end
        end
    end
    

    
    // Control similar a los registros vectoriales
    // Este always controla busy, vlr, counter, dirección, stride, indexed y máscara para la lectura
    // Funciona exactamente igual que el de escritura, pero sin capturar la máscara (aún no está implementada en la lectura)
    // La otra única diferencia es que no se comprueba que el dato entrante sea válido ya que estamos leyendo no escribiendo
    generate
        genvar r_gen;
        for (r_gen = 0; r_gen < MEM_READ_PORTS; r_gen = r_gen + 1) begin: read_gen
            always @(posedge clk)
            begin
                if (rst) begin
                    busy_read_reg[r_gen] <= 0;
                    vlr_read[r_gen] <= 0;
                    counter_read[r_gen] <= 0;
                    addr_read_reg[r_gen] <= 0;
                    stride_r_reg[r_gen] <= 0;
                    indexed_load_reg[r_gen] <= 0;
                    mask_reg_read[r_gen] <= 0;
                end else if (read_signal[r_gen] & ~busy_read_reg[r_gen])  begin
                    busy_read_reg[r_gen] <= 1'b1;
                    vlr_read[r_gen] <= VLR;
                    counter_read[r_gen] <= 1;
                    addr_read_reg[r_gen] <= address;
                    stride_r_reg[r_gen] <= stride;
                    indexed_load_reg[r_gen] <= indexed;
                    mask_reg_read[r_gen] <= mask;
                end else if (busy_read_reg) begin
                    if (counter_read[r_gen] == vlr_read[r_gen]) begin
                        counter_read[r_gen] <= 0;
                        busy_read_reg[r_gen] <= 1'b0;
                        stride_r_reg[r_gen] <= 0;
                        indexed_load_reg[r_gen] <= 0;
                    end else begin
                        if (indexed_load_reg[r_gen] & index_load[((DEPTH+VALID)*r_gen) + DEPTH]) begin
                            counter_read[r_gen] <= counter_read[r_gen] + 1;
                        end else if (~indexed_load_reg) begin
                            addr_read_reg[r_gen] <= addr_read_reg[r_gen] + stride_r_reg[r_gen];
                            counter_read[r_gen] <= counter_read[r_gen] + 1;
                        end
                    end
                end
            end
        end    
    endgenerate
    
    
    
    // Asignamos a las salidas busy, los registros busy correspondientes (de nuevo cuando hice esto no sabia que podia poner salidas como registros directamente)
    assign busy_write = busy_write_reg;
    assign busy_read  = busy_read_reg;
    
    
    
    
    // synthesis translate_off
  	
    reg [15:0] tics;
    always @(posedge clk) begin
    	if (rst) begin
    		tics <= 0;
    	end else begin
    		tics <= tics + 1;
    	end
    end
    
    generate
        genvar mg;
        for (mg = 0; mg < MEM_READ_PORTS; mg = mg + 1) begin: mem_port_gen
            always @(posedge clk) begin
                if (busy_read_reg[mg]) begin
//                    $display ("Lectura memoria | puerto: %d | posición: %d | leido : %d | tic : %d", addr_read, mg, data_in_load[mg*DATA_WIDTH +: DATA_WIDTH], tics);
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
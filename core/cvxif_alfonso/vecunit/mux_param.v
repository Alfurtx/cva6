`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.10.2023 08:16:48
// Design Name: 
// Module Name: mux_param
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
// Multiplexor parametrizable activable, de tal forma 
// que durante ciclos x deja pasar datos en base a la 
// seleccion enviada
//////////////////////////////////////////////////////////////////////////////////

module mux_param #(
    parameter NUM_INPUTS = 20, 
    parameter DATA_WIDTH = 32, 
    parameter VALID = 1, 
    parameter MVL=32
  ) (
	input clk,                                                  // Señal de reloj
	input rst,                                                  // Señal de reset
    input start,                                                // Señal de start para el mux
    input [(DATA_WIDTH+VALID)*NUM_INPUTS-1:0] data_i,           // Entrada de datos: un bus de anchura (data_width + valid) * numero de entradas
    input [bitwidth(NUM_INPUTS)-1:0]          sel,              // Entrada de seleccion
    input [bitwidth(MVL):0]                   VLR,              // Entrada de VLR
    output [DATA_WIDTH+VALID-1:0]             data_o            // Salida para el elemento seleccionado entre las entradas
  );
    
    localparam sel_width     = bitwidth(NUM_INPUTS);            // Parámetro auxiliar que indica la anchura de la seleccion
    localparam counter_width = bitwidth(MVL);                   // Parámetro auxiliar que indica la anchura del contador
    localparam valid_pos     = DATA_WIDTH;                      // Parámetro auxiliar que indica la posicion del bit de valid en un bus
    
    wire [(DATA_WIDTH+VALID)-1:0] inputs[0:NUM_INPUTS-1];       // Wire para separar el bus de entrada en cada una de entradas de inputs: primer dato en inputs[0],
                                                                // segundo dato en inputs[1], tercer dato en inputs[2]...
    reg [bitwidth(MVL):0]          counter;                     // Contador para contar los elementos validos que hemos dejado pasar
    reg [bitwidth(MVL):0]          vlr_reg;                     // Registro para almacenar el VLR
    reg [bitwidth(NUM_INPUTS)-1:0] sel_reg;                     // Registro para almacenar la selección que nos han indicado
    reg                               busy;                     // Registro para saber si el mux está ocupado
    
    
    
    // Generate para separar el bus de entrada en el wire "inputs" //
    // Si declaro el multiplexor como que tiene 4 entradas, 
    // el bus data_i irá de 0 a 131 (33*4 = 132)
    // Por lo que para almacenar sobre inputs[] haré:
    // inputs[0] = data_i del bit 0 al bit 32
    // inputs[1] = data_i del bit 33 al bit 55....
    // (etc).
    // Esta lógica se repite mucho a en todo el proyecto
    generate
        genvar i;
        for (i=0; i < NUM_INPUTS; i = i+1)
        begin: in_wires
            assign inputs[i] = data_i[(DATA_WIDTH + VALID) * (i + 1) - 1 :  (DATA_WIDTH + VALID) * i];
        end
    endgenerate
    
    // Aquí compruebo si estoy busy
    // Si busy = 1, asigno a la salida el elemento de inputs indicado por la seleccion sel_reg
    assign data_o = (busy) ? inputs[sel_reg] : 0;
    
    
    
    // Bloque always para gestionar los registros
    // Señal de reset -> se reinician todos los registros
    // Señal de inicio (y el multiplexor no está ocupado) -> busy a 1, capturo VLR, capturo seleccion e inicio contador
    // Mientras el mux esté ocupado y el dato que llega a través de la entrada seleccionada sea valid:
    // Si counter < vlr, incrementar counter
    // Si counter == vlr, se han procesado todos los elementos, reiniciar counter, busy a 0 y reiniciar el resto de registros.
    always @(posedge clk) begin
    	if (rst) begin
    		busy <= 0;
    		vlr_reg <= 0;
    		sel_reg <= 0;
    		counter <= 0;
    	end else if (start & ~busy) begin
            busy <= 1'b1;
            vlr_reg <= VLR;
            sel_reg <= sel;
            counter <= 1;
        end else if (busy & inputs[sel_reg][valid_pos] & (counter < vlr_reg)) begin
            counter <= counter + 1'b1;
        end else if (busy & inputs[sel_reg][valid_pos] & (counter == vlr_reg)) begin
            counter <= {counter_width{1'b0}};
            busy <= 1'b0;
            sel_reg <= {sel_width{1'b0}};
            vlr_reg <= {counter_width{1'b0}};
        end
    end
    
    
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    
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

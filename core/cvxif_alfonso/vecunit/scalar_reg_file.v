`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/13/2024 10:43:40 AM
// Design Name: 
// Module Name: scalar_reg_file
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


module scalar_reg_file #(
    parameter DATA_WIDTH = 32,
    parameter VALID = 1,
    parameter MASK = 1,
    parameter NUM_ESC_REGS = 32
)(
    input  clk,                                         // Señal de reloj
    input  rst,                                         // Señal de reset
    input  we,                                          // Señal de escritura
    input  [VALID+MASK+DATA_WIDTH-1:0]  write_data,     // Dato entrante de escritura
    input  [bitwidth(NUM_ESC_REGS)-1:0] esc_addr_w,     // Registro a escribir
    input  re_a,                                        // Señal de lectura del puerto a (1)
    input  re_b,                                        // Señal de lectura del puerto b (2)
    input  [bitwidth(NUM_ESC_REGS)-1:0] esc_addr_a,     // Registro a leer por el puerto a (1)
    input  [bitwidth(NUM_ESC_REGS)-1:0] esc_addr_b,     // Registro a leer por el puerto b (2)
    output [DATA_WIDTH+VALID-1:0]       out_a,          // Salida de datos del puerto a (1)
    output [DATA_WIDTH+VALID-1:0]       out_b,          // Salida de datos del puerto b (1)
    output [bitwidth(NUM_ESC_REGS)-1:0] esc_reg_w_busy, // Salida registrada que indica qué registro se está escribiendo/se va a escribir
                                                        // (en el caso de que se esté escribiendo)
    output reg esc_w_busy                               // Salida registrada que indica que se está escribiendo/esperando para escribir
    );
    
    reg [DATA_WIDTH-1:0] reg_file [0:NUM_ESC_REGS-1];   // Banco de registros
    
    reg [bitwidth(NUM_ESC_REGS-1):0] esc_addr_w_reg;    // Registro para almacenar qué registro se va a escribir
    
    
    // Salida de datos de los puertos a y b
    // Si reciben su señal de lectura, sacan por su correspondiente puerto
    // el dato del registro "esc_addr_x", precedido por un bit de validez puesto a 1
    // Mientras la señal de lectura permanezca a 0, la salida por estos puertos tendrá el valid a 0
    assign out_a = (re_a) ? {1'b1, reg_file[esc_addr_a]} : 33'b0;
    assign out_b = (re_b) ? {1'b1, reg_file[esc_addr_b]} : 33'b0;
    
    // El dato que se envia por la salida que indica qué registro está siendo escrito/se va a escribir
    // viene dado por el registro esc_addr_w_reg, que indica qué registro se va a escribir
    assign esc_reg_w_busy = esc_addr_w_reg;
    
    // Bloque always para contolar la escritura del banco de registros
    integer i;
    always @(posedge clk) begin
        // Señal de reset -> se reinician todos los registros a 0
        if(rst) begin
            for (i = 0; i < NUM_ESC_REGS; i = i+1) begin
                reg_file[i] <= 0;
            end
            // Despues, se pueden iniciar algunas posiciones a ciertos valores segun conveniencia
            reg_file[1] <= 32'b0_10000001_01000000000000000000000; // 5
            reg_file[2] <= 32'b0_10000010_01000000000000000000000;
            reg_file[3] <= 32'b0_10000000_00000000000000000000000; // 2
            reg_file[4] <= 2;
            reg_file[5] <= 40;
            reg_file[6] <= 4'b0111;
            reg_file[7] <= 4'b1111;
            reg_file[8] <= 8; // 16 // 0
            reg_file[9] <= 8; // 64 // 8
            reg_file[10] <= 62;
            reg_file[11] <= 0;
            reg_file[12] <= 8; // 32 // 8
            esc_w_busy <= 0;
            esc_addr_w_reg <= 0;
        // Señal de escritura: se pone esc_w_busy a 1 y se captura
        // esc_addr_w sobre esc_addr_w_reg, para así saber qué registro se va a escribir
        end else if (we) begin
            esc_w_busy <= 1'b1;
            esc_addr_w_reg <= esc_addr_w;
            // Por si acaso, se comprueba si en este mismo ciclo me llega un dato entrante a escribir
            // Si es así lo escribo y vuelvo a poner busy a 0 (esto creo que no pasa nunca, supongo que lo puse
            // por si acaso)
            if (write_data[DATA_WIDTH] & write_data[DATA_WIDTH+MASK]) begin
                reg_file[esc_addr_w] <= write_data[DATA_WIDTH-1:0];
                esc_w_busy <= 1'b0;
            end
        // Si la escritura está busy y el dato entrante es válido
        // se escribe el dato en el registro indicado por
        // esc_addr_w_reg y se pone el busy de vuelta a 0
        // Mientras no llegue un dato valid a escribir, busy permanecerá a 1
        end else if (esc_w_busy & write_data[DATA_WIDTH+MASK]) begin
            reg_file[esc_addr_w_reg] <= write_data[DATA_WIDTH-1:0];
            esc_w_busy <= 1'b0;
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

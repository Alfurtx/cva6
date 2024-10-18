`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/31/2024 11:50:58 AM
// Design Name: 
// Module Name: interfaz_div_f
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


module interfaz_div_f #(
    parameter DATA_WIDTH = 32,
    parameter MVL = 32,
    parameter ID = 0
) (
    input clk,
    input reset,
    input [32:0] operand_a,  // Valid,operand_a[31:0]
    input [32:0] operand_b, // Valid,operand_b[31:0]
    input [bitwidth(MVL):0] vlr_i,
    input [MVL-1:0] mask_i,
    input operation_code_i, // 0 => Addition
                            // 1 => Substraction
    input [1:0] cont_esc_i,
    input [1+DATA_WIDTH-1:0] op_esc_i,
    input start,
    input[1:0] code_round, // 00 => Truncate
                           // 01 => Round to nearest tie to event
                           // 10 => Towards + infinite
                           // 11 => Towards - infinite
   // OUTPUTS //
    output [33:0] out, // Valid,Mask,result[31:0]
    output reg busy 
    );
    
    reg [bitwidth(MVL):0] vlr_reg;                            // Registro para almacenar el vlr
    reg [bitwidth(MVL):0] count_mask;                         // Contador para indexar la máscara: se usa para elegir el bit de la máscara a enviar al operador
    reg [bitwidth(MVL):0] count_end;                          // Contador de elementos finalizados: cuenta los resultados que han atravesado ya todo el operador
    reg [1:0] cont_esc_reg;                                   // Registro para almacenar el control escalar
    reg [1+DATA_WIDTH-1:0] op_esc_reg;                        // Registro para almacenar el operando escalar
    reg [MVL-1:0] mask_reg;                                   // Registro para almacenar la máscara
    
    wire [DATA_WIDTH-1:0] value_a;                            // Wire que contiene el valor del operando 1
    wire [DATA_WIDTH-1:0] value_b;                            // Wire que contiene el valor del operando 2
    wire [DATA_WIDTH-1:0] value_result;                       // Wire que contiene el valor del resultado
    
    wire [32:0] true_operand_a;                               // Wire que contiene el operando 1 correcto (se elige entre operando 1 y operando escalar)
    wire [32:0] true_operand_b;                               // Wire que contiene el operando 2 correcto (se elige entre operando 2 y operando escalar)
                                                              // Este segundo caso no se da por lo que ya he comentado en otros lados
                                                              
    wire [33:0] result_div;                                                               
    
    assign value_a = true_operand_a[DATA_WIDTH-1:0];          // Value_a recibe el valor de true_operand_a (a es el operando 1)
    assign value_b = true_operand_b[DATA_WIDTH-1:0];          // Value_b recibe el valor de true_operand_b (b es el operando 2)
    assign out = result_div;  // Value result recibe el valor del resultado final generado por el operador

// Aquí se asignan los true_operands
// En ambos casos se comprueba el control escalar para ver si hay operando escalar y cuál es: el fuente 1 o el fuente 2
// De nuevo por el cambio en la decodificación, nunca se dará el caso de que el fuente 2 sea el escalar
// De todas formas se explica: 
// true_operand_a:
//   si no hay operando escalar (o lo hay pero es el 2): true_operand_a = operand_a
//   si hay operando escalar y es el 1: true_operand_a = {bit valid del operando escalar capturado, operador escalar capturado}
// El caso para true_operand_b es igual pero opuesto
assign true_operand_a = (~cont_esc_reg[1] | (cont_esc_reg[1] &  cont_esc_reg[0]))  ? operand_a : {op_esc_reg[DATA_WIDTH],op_esc_reg[DATA_WIDTH-1:0]};
assign true_operand_b = (~cont_esc_reg[1] | (cont_esc_reg[1] & ~cont_esc_reg[0]))  ? operand_b : {op_esc_reg[DATA_WIDTH],op_esc_reg[DATA_WIDTH-1:0]};                                    
    
    DIV_SEG #(
        .DATA_WIDTH ( DATA_WIDTH ),
        .MVL ( MVL ),
        .ID ( ID )
    ) divisor_float (
        .clk ( clk ),
        .reset ( reset ),
        .start ( start ),
        .mask_i (  ),
        .operand_a (  ),
        .operand_ (  ),      // Valid operand[31:0]
        .final_result ( result_div ),  // Valid,Mask,result[31:0]
        .busy (  )
    );
                                                                  
    always@(posedge clk)
    begin
        if(reset) begin
            vlr_reg <= 0;
            count_mask <= 1;
            count_end <= 1;
            cont_esc_reg <= 0;
            op_esc_reg <= 0;
            mask_reg <= 0;
            busy <= 0;
        end if (start) begin
            vlr_reg <= vlr_i;
            count_mask <= 1;
            count_end <= 1;
            mask_reg <= mask_i;
            cont_esc_reg <= cont_esc_i;
            op_esc_reg <= op_esc_i;
            busy <= 1;
        end else if (busy) begin
            if((result_div[0] & count_end < vlr_reg) & (vlr_reg > 0)) begin
                count_end <= count_end + 1;
            end else if (result_div[0] | (vlr_reg == 0)) begin
                count_end <= 1;
                busy <= 0;
            end
            if(count_mask < vlr_reg) begin
                count_mask <= count_mask + 1;
            end else begin
                count_mask <= 1;
            end
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

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.12.2023 17:04:41
// Design Name: 
// Module Name: genpp
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
// Generador de productos parciales
//////////////////////////////////////////////////////////////////////////////////

// 29 feb Este modulo se encarga de generar los productos parciales a partir de las mantisas ya con el hidden bit
module genpp #(parameter NPP = 24, WIDTH = 48) (
    input wire [NPP - 2:0] MA,MB,
    input wire [7:0] EA,EB,
    output reg [(NPP * WIDTH) - 1 : 0] pp // Array de 24 productos parciales de 48 bits
);

wire [23:0] ma,mb;

assign ma = |EA ? {1'b1,MA} : {1'b0,MA};
assign mb = |EB ? {1'b1,MB} : {1'b0,MB};

    integer i;
    always @* begin
    for (i = 0; i < NPP; i = i + 1) begin
        if (mb[i] == 1) begin
            pp[(i * WIDTH) +: WIDTH] = (ma << i); 
        end else begin
            pp[(i * WIDTH) +: WIDTH] = 48'd0; // Asignamos ceros si mb[i] no es 1
        end
    end
end




endmodule


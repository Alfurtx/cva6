`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.11.2023 15:49:51
// Design Name: 
// Module Name: consumidor
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


module consumidor(
        input clk_i,
        input [5:0] trabajo,
        output busy
    );
    
    reg busy_r;
    reg [1:0] contador;
    reg [5:0] trabajo_recibido;
    
    assign busy = busy_r;
    
//    always @(posedge clk_i) begin
//        if (entrada) begin
//            busy_r <= 1'b1;
//            contador <= 2'b11;
//        end else if (~entrada && contador) begin
//            contador <= contador - 1;
//        end else if (~contador) begin
//            busy_r <= 0;
//        end
//    end

    always @(posedge clk_i) begin
        if (trabajo) begin
            busy_r <= 1'b1;
            trabajo_recibido <= trabajo;
            contador <= 2'b11;
        end else begin
            if (contador > 0)
                contador <= contador - 1;
            else begin
                busy_r <= 1'b0;
                trabajo_recibido <= 0;
            end
        end
    end
    
    initial
    busy_r <= 0;
endmodule

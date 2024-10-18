// Original Author: Alfonso Amorós
`include "vecunit/unit_dec_mem.sv"

module cvxif_unidad_vectorial
#(
    // CVXIF Types
    parameter int unsigned XLEN          = 32, // Register size?
    parameter int unsigned NUM_REG_PORTS = 2
    parameter type cvxif_req_t           = logic,
    parameter type cvxif_resp_t          = logic,
) (
    input  logic        clk_i,        // Clock
    input  logic        rst_ni,       // Asynchronous reset active low
    input  cvxif_req_t  cvxif_req_i,
    output cvxif_resp_t cvxif_resp_o
);

// Señales que se conectan con la unidad vectorial
reg         vec_valid;
wire        vec_full;
reg [31:0]  vec_instr;
wire 	    empty_placeholder;
wire [31:0] data_read_o_placeholder;
wire [31:0] data_write_o_placeholder;

// Estos son los registros donde pedir datos (supongo que tambien donde se
// escribiran)
reg [XLEN-1:0] registers [NUM_REG_PORTS-1:0];

// Señales leyendo de CVXIF_REQ
// NOTA: no estan las señales de commit y result. Mi suposicion respecto a las
// de commit es que como no esta supported la ejecucion especulativa,
// directamente la ignoran.
x_compressed_req_t compressed_req;
logic              compressed_valid;
x_issue_req_t      issue_req;
logic              issue_valid;
x_register_t       register;
logic              register_valid;

assign compressed_req   = cvxif_req_i.compressed_req;
assign compressed_valid = cvxif_req_i.compressed_valid;
assign issue_req        = cvxif_req_i.issue_req;
assign issue_valid      = cvxif_req_i.issue_valid;
assign register         = cvxif_req_i.register;
assign register_valid   = cvxif_req_i.register_valid;

// Señales conectadas directamente con CVXIF_RESP 
logic               compressed_ready;
x_compressed_resp_t compressed_resp;
logic               issue_ready;
x_issue_resp_t      issue_resp;
logic               register_ready;
logic               result_valid;
x_result_t          result;

// Hay que rellenar la estructura CVXIF_RESP
assign cvxif_resp_o.compressed_ready = compressed_ready;
assign cvxif_resp_o.compressed_resp  = compressed_resp;
assign cvxif_resp_o.issue_ready      = issue_ready;
assign cvxif_resp_o.issue_resp       = issue_resp;
assign cvxif_resp_o.register_ready   = register_ready;
assign cvxif_resp_o.result_valid     = result_valid;
assign cvxif_resp_o.result           = result;

unit_dec_mem #(
) udm (
	.clk(clk_i),
	.rst(~rst_ni),
	.valid(vec_valid),
	.instr(vec_instr),
	.full(vec_full),
	.empty(empty_placeholder),              // INUTIL
	.data_read_o(data_read_o_placeholder),  // INUTIL
	.data_write_o(data_write_o_placeholder) // INUTIL
);

endmodule

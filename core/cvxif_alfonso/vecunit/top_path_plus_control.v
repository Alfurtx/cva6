`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.11.2023 12:04:38
// Design Name: 
// Module Name: top_path_plus_control
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

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// En este módulo sólamente se comunican las entradas y salidas de los módulos de las distintas capas  //
/////////////////////////////////////////////////////////////////////////////////////////////////////////


module top_path_plus_control #(
    parameter NUM_REGS        = 8,                 // Número de registros vectoriales
    parameter NUM_ESC_REGS    = 32,            // Número de registros escalares
    parameter NUM_WRITE_PORTS = 1,          // Número de puertos de escritura en los registros vectoriales
    parameter NUM_READ_PORTS  = 2,           // Número de puertos de lectura en los registros vectoriales
    parameter DATA_WIDTH      = 32,              // Tamaño del dato con el que se trabaja (matener a 32)
    parameter VALID           = 1,                    // Anchura del bit de validez (mantener a 1)
    parameter MASK            = 1,                     // Anchura del bit de máscara (mantener a 1)
    parameter WIDTH           = DATA_WIDTH + VALID,   // Anchura de dato + bit de máscara
    parameter MVL             = 32,                     // Tamaño máximo de vector permitido
    parameter ADDRESS_WIDTH   = 10,           // Anchura de las direcciones de memoria -> define el tamaño de la memoria
    parameter MEM_READ_PORTS  = 2,           // Número de puertos de lectura en memoria
    parameter MAX_STRIDE      = 16,              // Stride máximo en los accesos regulares no secuenciales
    parameter NUM_ALUS        = 2,                 // Número de alus
    parameter NUM_MULS        = 2,                 // Número de multiplicadores
    parameter NUM_DIVS        = 2,                 // Número de divisores
    parameter NUM_SQRTS       = 2,                // Número de operadores de raíz cuadrada
    parameter NUM_LOGICS      = 2,               // Número de operadores multifunción
    parameter NUM_LOGIC_OPS   = bitwidth(18), // Número de operaciones en el operador multifunción
    parameter NUM_F_ALUS      = 2,               // Número de alus float
    parameter NUM_F_MULS      = 2,               // Número de multiplicadores float
    parameter NUM_F_DIVS      = 2,               // Número de divisores float
    parameter NUM_F_SQRTS     = 2,              // Número de operadores de raíz cuadrada float
    parameter NUM_F_ADDMULS   = 2,            // Número de operadores addmul (NO SE USA)
    parameter SIZE_QUEUE      = 16               // Tamaño de la cola FIFO
  ) (
        
    // Todas las siguientes señales ya han sido explicadas en el resto de módulos
    input clk,
    input rst,                              
    input valid,
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
    input [bitwidth(NUM_REGS)-1:0]     src1,
    input [bitwidth(NUM_REGS)-1:0]     src2,
    input [bitwidth(NUM_ESC_REGS)-1:0] src1_esc,
    input [bitwidth(NUM_ESC_REGS)-1:0] src2_esc,
    input [bitwidth(NUM_REGS)-1:0]     dst,
    input [bitwidth(NUM_ESC_REGS)-1:0] dst_esc,
    output full,
    output empty,
    
    ///////////////////////////////////////////////////
    //  PUERTOS PARA LA COMUNICACIÓN CON LA MEMORIA   //
    ///////////////////////////////////////////////////
    input [(DATA_WIDTH*MEM_READ_PORTS)-1:0] mem_data_read_in,   // Dato entrante que ha sido leido de memoria
    output [WIDTH+MASK-1:0]               mem_data_write_out,   // Dato saliente para escribirlo en memoria
    output [(ADDRESS_WIDTH*MEM_READ_PORTS)-1:0]    addr_read,   // Direccion/es de lectura
    output [ADDRESS_WIDTH-1:0]                    addr_write,   // Dirección de escritura
    output mem_w_busy                                           // Puerto de escritura de memoria ocupado
    );
    
    /////////////////////////////////////////////////////////////////////////////////
    // Wires para pasar inputs/outputs entre modulos //
    /////////////////////////////////////////////////////////////////////////////////
    
    //  En general, los nombres de los wires usados tienen los mismos nombres que los propios puertos de los modulos
    
    wire [MEM_READ_PORTS-1:0]                    mem_r_busy;                 // Busy lectura memoria:                                          Datapath -> CU
    wire [NUM_WRITE_PORTS*NUM_REGS-1:0]          bank_w_busy;                // Busy escritura banco:                                          Datapath -> CU
    wire [NUM_READ_PORTS*NUM_REGS-1:0]           bank_r_busy;                // Busy lectura banco:                                            Datapath -> CU
    wire [NUM_ALUS-1:0]                          alu_busy;                   // Alu busy:                                                      Datapath -> CU
    wire [NUM_F_ALUS-1:0]                        alu_f_busy;                 // Alu float busy:                                                Datapath -> CU
    wire [NUM_MULS-1:0]                          mul_busy;                   // Multiplicador busy:                                            Datapath -> CU
    wire [NUM_F_MULS-1:0]                        mul_f_busy;                 // Multiplicador float busy:                                      Datapath -> CU
    wire [NUM_DIVS-1:0]                          div_busy;                   // Divisor busy:                                                  Datapath -> CU
    wire [NUM_F_DIVS-1:0]                        div_f_busy;                 // Divisor float busy:                                            Datapath -> CU
    wire [NUM_SQRTS-1:0]                         sqrt_busy;                  // Raíz cuadrada busy:                                            Datapath -> CU
    wire [NUM_F_SQRTS-1:0]                       sqrt_f_busy;                // Raíz cuadrada float                                            Datapath -> CU
    wire [NUM_F_ADDMULS-1:0]                     addmul_f_busy;              // NADA
    wire [NUM_LOGICS-1:0]                        logic_busy;                 // Multifunción busy:                                             Datapath -> CU
    wire [VALID+MASK-1:0]                        mask_bit_o;                 // Bit de máscara para copiar sobre CU                            Datapath -> CU
    wire [bitwidth(MVL):0]                       VLR;                        // Registro VLR:                                                  CU -> Datapath
    wire                                         float_signal;               // Operacion float                                                CU -> Datapath
    wire                                         mem_w_signal;               // Señal de escritura en memoria:                                 CU -> Datapath
    wire [MEM_READ_PORTS-1:0]                    mem_r_signal;               // Señal de lectura en memoria:                                   CU -> Datapath
    wire [ADDRESS_WIDTH-1:0]                     addr_signal;                // Direccion de escritura/lectura                                 CU -> Datapath
    wire [bitwidth(MAX_STRIDE)-1:0]              stride_signal;              // Stride a aplicar sobre las direcciones:                        CU -> Datapath
    wire                                         indexed_signal;             // Para indicar que la load/store es indexada                     CU -> Datapath
    wire [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0] indexed_st_sel;             // Seleccion del registro para obtener los indices de la store    CU -> Datapath
    wire [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0] indexed_ld_sel;             // Seleccion del registro para obtener los indices de la load     CU -> Datapath
    wire [NUM_WRITE_PORTS*NUM_REGS-1:0]          bank_w_signal;              // Señal de escritura en banco:                                   CU -> Datapath
    wire [NUM_WRITE_PORTS*NUM_REGS-1:0]          masked_vid_signal;          // Señal de escritura vid con máscara:                            CU -> Datapath 
    wire [NUM_READ_PORTS*NUM_REGS-1:0]           bank_r_signal;              // Señal de lectura en banco:                                     CU -> Datapath
    wire [NUM_REGS-1:0]                          first_elem;                 // Señal de primer elemento escrito:                              CU -> Datapath
    wire                                         op;                         // Operacion a realizar en alu:                                   CU -> Datapath
    wire [NUM_ALUS-1:0]                          start_alu;                  // Señal de start para alus:                                      CU -> Datapath
    wire [NUM_F_ALUS-1:0]                        start_f_alu;                // Señal de start para alus float:                                CU -> Datapath
    wire [NUM_MULS-1:0]                          start_mul;                  // Señal de start para multiplicadores:                           CU -> Datapath
    wire [NUM_F_MULS-1:0]                        start_f_mul;                // Señal de start para multiplicadores float:                     CU -> Datapath
    wire [NUM_DIVS-1:0]                          start_div;                  // Señal de start para divisores:                                 CU -> Datapath
    wire [NUM_F_DIVS-1:0]                        start_f_div;                // Señal de start para divisores float:                           CU -> Datapath
    wire                                         op_div;                     // Selector de operación de division                              CU -> Datapath
    wire [NUM_SQRTS-1:0]                         start_sqrt;                 // Señal de start para sqrts:                                     CU -> Datapath
    wire [NUM_F_SQRTS-1:0]                       start_f_sqrt;               // Señal de start para sqrts float:                               CU -> Datapath
    wire [NUM_F_ADDMULS-1:0]                     start_f_addmul;             // NO SE USA
    wire [NUM_LOGICS-1:0]                        start_logic;                // Señal de start para operadores multifunción:                   CU -> Datapath
    wire [NUM_LOGIC_OPS-1:0]                     sel_logic_op;               // Señal para indicar qué operacion multifunción realizar         CU -> Datapath
    wire [1:0]                                   control_esc;                // Control escalar                                                CU -> Datapath
    wire [VALID+DATA_WIDTH-1:0]                  operand_esc;                // Operando escalar                                               CU -> Datapath
    wire [MVL-1:0]                               mask;                       // Mascara a aplicar                                              CU -> Datapath
    wire [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0] alu_mux_sel_op1;            // Selección del multiplexor de operador 1:                       CU -> Datapath
    wire [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0] alu_mux_sel_op2;            // Selección del multiplexor de operador 2:                       CU -> Datapath
    wire [bitwidth(NUM_READ_PORTS*NUM_REGS)-1:0] mem_mux_sel;                // Seleccion del multiplexor de escritura en memoria:             CU -> Datapath
    wire [bitwidth(NUM_ALUS+NUM_MULS+NUM_DIVS+
          NUM_SQRTS+NUM_F_ALUS+NUM_F_MULS+
          NUM_F_DIVS+NUM_F_SQRTS+NUM_LOGICS+
          MEM_READ_PORTS)-1:0]                   bank_write_sel;             // Seleccion del mux de escritura en registros:                   CU -> Datapath
    wire                                         start_esc_mux;              // Señal de start para el mux del resultado escalar               CU -> Datapath
    wire [bitwidth(NUM_ALUS+NUM_MULS+NUM_DIVS+
          NUM_SQRTS+NUM_F_ALUS+NUM_F_MULS+
          NUM_F_DIVS+NUM_F_SQRTS+ NUM_LOGICS+
          MEM_READ_PORTS)-1:0]                   esc_mux_sel;                // Señal de selección para el mux del resultado escalar           CU -> Datapath
    wire                                         start_mux_mask;             // Señal de start para el mux de máscara:                         CU -> Datapath
    wire [bitwidth(NUM_WRITE_PORTS)-1:0]         mask_mux_sel;               // Selección del multiplexor de máscara:                          CU -> Datapath
      
    // Señales de instrucciones                                                                                                                FIFO -> CU
    wire                                         setvl_o;
    wire                                         add_o;
    wire                                         sub_o;
    wire                                         mul_o;
    wire                                         div_o;
    wire                                         rem_o;
    wire                                         sqrt_o;
    wire                                         addmul_o;
    wire                                         peq_o;
    wire                                         pne_o;
    wire                                         plt_o;
    wire                                         sll_o;
    wire                                         srl_o;
    wire                                         sra_o;
    wire                                         log_xor_o;
    wire                                         log_or_o;
    wire                                         log_and_o;
    wire                                         sgnj_o;
    wire                                         sgnjn_o;
    wire                                         sgnjx_o;
    wire                                         pxor_o;
    wire                                         por_o;
    wire                                         pand_o;
    wire                                         vid_o;
    wire                                         vcpop_o;
    wire                                         strided_o;
    wire                                         float_o;
    wire                                         masked_op_o;
    wire [1:0]                                   esc_o;
    wire                                         load_o;
    wire                                         iload_o;
    wire                                         store_o;
    wire                                         istore_o;
    wire [bitwidth(NUM_REGS)-1:0]                src1_o;
    wire [bitwidth(NUM_REGS)-1:0]                src2_o;
    wire [bitwidth(NUM_ESC_REGS)-1:0]            src1_esc_o;
    wire [bitwidth(NUM_ESC_REGS)-1:0]            src2_esc_o;
    wire [bitwidth(NUM_REGS)-1:0]                dst_o;
    wire [bitwidth(NUM_ESC_REGS)-1:0]            dst_esc_o;
    
    
    // WIRES ENTRE UNIDAD DE CONTROL Y BANCO DE REGISTROS ESCALARES
    wire [DATA_WIDTH+VALID+MASK-1:0]             esc_result;
    wire                                         w_en;
    wire                                         re_a;
    wire                                         re_b;
    wire [bitwidth(NUM_ESC_REGS)-1:0]            esc_w_addr;
    wire [bitwidth(NUM_ESC_REGS)-1:0]            esc_ra_addr;
    wire [bitwidth(NUM_ESC_REGS)-1:0]            esc_rb_addr;
    wire                                         esc_w_busy;
    wire [bitwidth(NUM_ESC_REGS)-1:0]            esc_reg_busy;
    wire [DATA_WIDTH+VALID-1:0]                  esc_oa_cu;
    wire [DATA_WIDTH+VALID-1:0]                  esc_ob_cu;
    wire [DATA_WIDTH+VALID+MASK-1:0]             esc_result_cu_regfile;
    
    fifo_queue #(
      .SIZE          ( SIZE_QUEUE    ),
      .NUM_REGS      ( NUM_REGS      ),
      .NUM_ESC_REGS  ( NUM_ESC_REGS  ),
      .MVL           ( MVL           ),
      .ADDRESS_WIDTH ( ADDRESS_WIDTH ),
      .MAX_STRIDE    ( MAX_STRIDE    )
    ) fifo (
      //  INPUTS  //
      .clk           ( clk           ),
      .rst           ( rst           ),
      .valid         ( valid         ), // Asumo que el decodificador de instrucciones tiene una señal de valid (para indicar si se ha dejado o no de decodificar instrucciones) ME SIRVE COMO SEÑAL WRITE
      .setvl         ( setvl         ),
      .add           ( add           ),
      .sub           ( sub           ),
      .mul           ( mul           ),
      .div           ( div           ),
      .rem           ( rem           ),
      .sqrt          ( sqrt          ),
      .addmul        ( addmul        ),
      .peq           ( peq           ),
      .pne           ( pne           ),
      .plt           ( plt           ),
      .sll           ( sll           ),
      .srl           ( srl           ),
      .sra           ( sra           ),
      .log_xor       ( log_xor       ),
      .log_or        ( log_or        ),
      .log_and       ( log_and       ),
      .sgnj          ( sgnj          ),
      .sgnjn         ( sgnjn         ),
      .sgnjx         ( sgnjx         ),
      .pxor          ( pxor          ),
      .por           ( por           ),
      .pand          ( pand          ),
      .vid           ( vid           ),
      .vcpop         ( vcpop         ),
      .strided       ( strided       ),
      .float         ( float         ),
      .esc           ( esc           ),
      .masked_op     ( masked_op     ),
      .load          ( load          ),
      .iload         ( iload         ),
      .store         ( store         ),
      .istore        ( istore        ),
      .src1          ( src1          ),
      .src2          ( src2          ),
      .src1_esc      ( src1_esc      ),
      .src2_esc      ( src2_esc      ),
      .dst           ( dst           ),
      .dst_esc       ( dst_esc       ),
      .stalling      ( stall         ),
      //  OUTPUTS  //
      .setvl_o       ( setvl_o       ),
      .add_o         ( add_o         ),
      .sub_o         ( sub_o         ),
      .mul_o         ( mul_o         ),
      .div_o         ( div_o         ),
      .rem_o         ( rem_o         ),
      .sqrt_o        ( sqrt_o        ),
      .addmul_o      ( addmul_o      ),
      .peq_o         ( peq_o         ),
      .pne_o         ( pne_o         ),
      .plt_o         ( plt_o         ),
      .sll_o         ( sll_o         ),
      .srl_o         ( srl_o         ),
      .sra_o         ( sra_o         ),
      .log_xor_o     ( log_xor_o     ),
      .log_or_o      ( log_or_o      ),
      .log_and_o     ( log_and_o     ),
      .sgnj_o        ( sgnj_o        ),
      .sgnjn_o       ( sgnjn_o       ),
      .sgnjx_o       ( sgnjx_o       ),
      .pxor_o        ( pxor_o        ),
      .por_o         ( por_o         ),
      .pand_o        ( pand_o        ),
      .vid_o         ( vid_o         ),
      .vcpop_o       ( vcpop_o       ),
      .strided_o     ( strided_o     ),
      .float_o       ( float_o       ),
      .esc_o         ( esc_o         ),
      .masked_op_o   ( masked_op_o   ),
      .load_o        ( load_o        ),
      .iload_o       ( iload_o       ),
      .store_o       ( store_o       ),
      .istore_o      ( istore_o      ),
      .src1_o        ( src1_o        ),
      .src2_o        ( src2_o        ),
      .src1_esc_o    ( src1_esc_o    ),
      .src2_esc_o    ( src2_esc_o    ),
      .dst_o         ( dst_o         ),
      .dst_esc_o     ( dst_esc_o     ),
      .full          ( full          ),
      .empty         ( empty         )
    );
    ////////////////////////////////////////////////////////////////
    // Instanciación de la unidad de control //
    ////////////////////////////////////////////////////////////////
    
    control_unit_dchinue #(
      .NUM_REGS           ( NUM_REGS              ),
      .NUM_ESC_REGS       ( NUM_ESC_REGS          ),
      .NUM_WRITE_PORTS    ( NUM_WRITE_PORTS       ),
      .NUM_READ_PORTS     ( NUM_READ_PORTS        ),
      .DATA_WIDTH         ( DATA_WIDTH            ),
      .VALID              ( VALID                 ),
      .MASK               ( MASK                  ),
      .WIDTH              ( WIDTH                 ),
      .MVL                ( MVL                   ),
      .ADDRESS_WIDTH      ( ADDRESS_WIDTH         ),
      .MEM_READ_PORTS     ( MEM_READ_PORTS        ),
      .MAX_STRIDE         ( MAX_STRIDE            ),
      .NUM_ALUS           ( NUM_ALUS              ),
      .NUM_MULS           ( NUM_MULS              ),
      .NUM_DIVS           ( NUM_DIVS              ),
      .NUM_SQRTS          ( NUM_SQRTS             ),
      .NUM_LOGICS         ( NUM_LOGICS            ),
      .NUM_LOGIC_OPS      ( NUM_LOGIC_OPS         ),
      .NUM_F_ALUS         ( NUM_F_ALUS            ),
      .NUM_F_MULS         ( NUM_F_MULS            ),
      .NUM_F_DIVS         ( NUM_F_DIVS            ),
      .NUM_F_SQRTS        ( NUM_F_SQRTS           ),
      .NUM_F_ADDMULS      ( NUM_F_ADDMULS         )
    ) cu (
        ////////////////////
        //// Inputs ////
        ////////////////////
      .clk                ( clk                   ),
      .rst                ( rst                   ),
      .setvl              ( setvl_o               ),
      .add                ( add_o                 ),
      .sub                ( sub_o                 ),
      .mul                ( mul_o                 ),
      .div                ( div_o                 ),
      .rem                ( rem_o                 ),
      .sqrt               ( sqrt_o                ),
      .addmul             ( addmul_o              ),
      .peq                ( peq_o                 ),
      .pne                ( pne_o                 ),
      .plt                ( plt_o                 ),
      .sll                ( sll_o                 ),
      .srl                ( srl_o                 ),
      .sra                ( sra_o                 ),
      .log_xor            ( log_xor_o             ),
      .log_or             ( log_or_o              ),
      .log_and            ( log_and_o             ),
      .sgnj               ( sgnj_o                ),
      .sgnjn              ( sgnjn_o               ),
      .sgnjx              ( sgnjx_o               ),
      .pxor               ( pxor_o                ),
      .por                ( por_o                 ),
      .pand               ( pand_o                ),
      .vid                ( vid_o                 ),
      .vcpop              ( vcpop_o               ),
      .strided            ( strided_o             ),
      .float              ( float_o               ),
      .esc                ( esc_o                 ),
      .masked_op          ( masked_op_o           ),
      .load               ( load_o                ),
      .iload              ( iload_o               ),
      .store              ( store_o               ),
      .istore             ( istore_o              ),
      .src1               ( src1_o                ),
      .src2               ( src2_o                ),
      .src1_esc           ( src1_esc_o            ),
      .src2_esc           ( src2_esc_o            ),
      .dst                ( dst_o                 ),
      .dst_esc            ( dst_esc_o             ),
      .mem_w_busy         ( mem_w_busy            ),
      .mem_r_busy         ( mem_r_busy            ),
      .bank_w_busy        ( bank_w_busy           ),
      .bank_r_busy        ( bank_r_busy           ),
      .esc_w_busy         ( esc_w_busy            ),
      .esc_reg_busy       ( esc_reg_busy          ),
      .alu_busy           ( alu_busy              ),
      .alu_f_busy         ( alu_f_busy            ),
      .mul_busy           ( mul_busy              ),
      .mul_f_busy         ( mul_f_busy            ),
      .div_busy           ( div_busy              ),
      .div_f_busy         ( div_f_busy            ),
      .sqrt_busy          ( sqrt_busy             ),
      .sqrt_f_busy        ( sqrt_f_busy           ),
      .addmul_f_busy      ( addmul_f_busy         ),
      .logic_busy         ( logic_busy            ),
      .first_elem         ( first_elem            ),
      .mask_copy_i        ( mask_bit_o            ),
      .esc_data_i_a       ( esc_oa_cu             ),
      .esc_data_i_b       ( esc_ob_cu             ),
      .esc_data_result_i  ( esc_result            ),
      //////////////////////
      //// Outputs ////
      //////////////////////
      .VLR ( VLR ),
      .float_signal       ( float_signal          ),
      .mem_w_signal       ( mem_w_signal          ),
      .mem_r_signal       ( mem_r_signal          ),
      .addr_signal        ( addr_signal           ),
      .stride_out         ( stride_signal         ),
      .indexed_signal     ( indexed_signal        ),
      .indexed_st_sel     ( indexed_st_sel        ),
      .indexed_ld_sel     ( indexed_ld_sel        ),
      .bank_w_signal      ( bank_w_signal         ),
      .masked_vid_signal  ( masked_vid_signal     ),
      .esc_r_en_a         ( re_a                  ),
      .esc_r_en_b         ( re_b                  ),
      .esc_w_en           ( w_en                  ),
      .esc_w_addr         ( esc_w_addr            ),
      .esc_ra_addr        ( esc_ra_addr           ),
      .esc_rb_addr        ( esc_rb_addr           ),
      .esc_data_o         ( operand_esc           ),
      .esc_data_result_o  ( esc_result_cu_regfile ),
      .bank_r_signal      ( bank_r_signal         ),
      .op                 ( op                    ),
      .start_alu          ( start_alu             ),
      .start_f_alu        ( start_f_alu           ),
      .control_esc        ( control_esc           ),
      .mask_o             ( mask                  ),
      .start_mux_mask     ( start_mux_mask        ),
      .mask_mux_sel       ( mask_mux_sel          ),
      .start_mul          ( start_mul             ),
      .start_f_mul        ( start_f_mul           ),
      .start_div          ( start_div             ),
      .start_f_div        ( start_f_div           ),
      .op_div             ( op_div                ),
      .start_sqrt         ( start_sqrt            ),
      .start_f_sqrt       ( start_f_sqrt          ),
      .start_f_addmul     ( start_f_addmul        ),
      .start_logic        ( start_logic           ),
      .sel_logic_op       ( sel_logic_op          ),
      .alu_mux_sel_op1    ( alu_mux_sel_op1       ),  // no solo para la alu, se usa para todos los operadores (solo se activa uno en cada ciclo por lo que no generan colisiones)
      .alu_mux_sel_op2    ( alu_mux_sel_op2       ),
      .mem_mux_sel        ( mem_mux_sel           ),
      .bank_write_sel     ( bank_write_sel        ),
      .start_esc_mux      ( start_esc_mux         ),
      .esc_mux_sel        ( esc_mux_sel           ),
      .stalling           ( stall                 )
    );
    
    top_reg_mem_alu #(
      .NUM_REGS           ( NUM_REGS           ),
      .NUM_WRITE_PORTS    ( NUM_WRITE_PORTS    ),
      .NUM_READ_PORTS     ( NUM_READ_PORTS     ),
      .DATA_WIDTH         ( DATA_WIDTH         ),
      .VALID              ( VALID              ),
      .WIDTH              ( WIDTH              ),
      .MVL                ( MVL                ),
      .B_ADDRESS          ( ADDRESS_WIDTH      ),
      .MEM_READ_PORTS     ( MEM_READ_PORTS     ),
      .MAX_STRIDE         ( MAX_STRIDE         ),
      .NUM_ALUS           ( NUM_ALUS           ),
      .NUM_MULS           ( NUM_MULS           ),
      .NUM_DIVS           ( NUM_DIVS           ),
      .NUM_SQRTS          ( NUM_SQRTS          ),
      .NUM_LOGICS         ( NUM_LOGICS         ),
      .NUM_LOGIC_OPS      ( NUM_LOGIC_OPS      ),
      .NUM_F_ALUS         ( NUM_F_ALUS         ),
      .NUM_F_MULS         ( NUM_F_MULS         ),
      .NUM_F_DIVS         ( NUM_F_DIVS         ),
      .NUM_F_SQRTS        ( NUM_F_SQRTS        ),
      .NUM_F_ADDMULS      ( NUM_F_ADDMULS      )
    ) datapath (
      // Inputs
      .clk                ( clk                ),
      .rst                ( rst                ),
      .mem_w_signal       ( mem_w_signal       ),
      .mem_r_signal       ( mem_r_signal       ),
      .VLR                ( VLR                ),
      .float_signal       ( float_signal       ),
      .addr               ( addr_signal        ),
      .mem_data_read_in   ( mem_data_read_in   ),
      .stride_signal      ( stride_signal      ),
      .indexed_signal     ( indexed_signal     ),
      .indexed_st_sel     ( indexed_st_sel     ),
      .indexed_ld_sel     ( indexed_ld_sel     ),
      .bank_w_signal      ( bank_w_signal      ),
      .masked_vid_signal  ( masked_vid_signal  ),
      .bank_r_signal      ( bank_r_signal      ),
      .alu_mux_sel_op1    ( alu_mux_sel_op1    ),
      .alu_mux_sel_op2    ( alu_mux_sel_op2    ),
      .mem_mux_sel        ( mem_mux_sel        ),
      .bank_write_sel     ( bank_write_sel     ),
      .start_esc_mux      ( start_esc_mux      ),
      .esc_mux_sel        ( esc_mux_sel        ),
      .control_esc        ( control_esc        ),
      .operand_esc        ( operand_esc        ),
      .start_alu          ( start_alu          ),
      .start_f_alu        ( start_f_alu        ),
      .opcode             ( op                 ),
      .start_mul          ( start_mul          ),
      .start_f_mul        ( start_f_mul        ),
      .start_div          ( start_div          ),
      .start_f_div        ( start_f_div        ),
      .op_div             ( op_div             ),
      .start_sqrt         ( start_sqrt         ),
      .start_f_sqrt       ( start_f_sqrt       ),
      .start_f_addmul     ( start_f_addmul     ),
      .start_logic        ( start_logic        ),
      .sel_logic_op       ( sel_logic_op       ),
      .start_mux_mask     ( start_mux_mask     ),
      .mask               ( mask               ),
      .mask_mux_sel       ( mask_mux_sel       ),
      
      // Outputs
      .mem_data_write_out ( mem_data_write_out ),
      .addr_write         ( addr_write         ),
      .addr_read          ( addr_read          ),
      .mem_busy_w         ( mem_w_busy         ),
      .mem_busy_r         ( mem_r_busy         ),
      .bank_w_busy        ( bank_w_busy        ),
      .bank_r_busy        ( bank_r_busy        ),
      .first_elem         ( first_elem         ),
      .alu_busy           ( alu_busy           ),
      .alu_f_busy         ( alu_f_busy         ),
      .mul_busy           ( mul_busy           ),
      .mul_f_busy         ( mul_f_busy         ),
      .div_busy           ( div_busy           ),
      .div_f_busy         ( div_f_busy         ),
      .sqrt_busy          ( sqrt_busy          ),
      .sqrt_f_busy        ( sqrt_f_busy        ),
      .addmul_f_busy      ( addmul_f_busy      ),
      .logic_busy         ( logic_busy         ),
      .mask_bit_o         ( mask_bit_o         ),
      .esc_result         ( esc_result         )
    );

    
    scalar_reg_file #(
      .DATA_WIDTH     ( DATA_WIDTH            ),
      .VALID          ( VALID                 ),
      .MASK           ( MASK                  ),
      .NUM_ESC_REGS   ( NUM_ESC_REGS          )
    ) esc_reg_file (
      .clk            ( clk                   ),
      .rst            ( rst                   ),
      .we             ( w_en                  ),
      .write_data     ( esc_result_cu_regfile ),
      .esc_addr_w     ( esc_w_addr            ),
      .re_a           ( re_a                  ),
      .re_b           ( re_b                  ),
      .esc_addr_a     ( esc_ra_addr           ),
      .esc_addr_b     ( esc_rb_addr           ),
      .out_a          ( esc_oa_cu             ),
      .out_b          ( esc_ob_cu             ),
      .esc_reg_w_busy ( esc_reg_busy          ),
      .esc_w_busy     ( esc_w_busy            )
    );
    
    
    
    
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

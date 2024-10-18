`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/28/2024 12:21:42 PM
// Design Name: 
// Module Name: vect_instr_decoder
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Codificación detallada en el github de la extension                                                        //
// Formatos instrucciones:                                                                                    //
// Memoria - https://github.com/riscv/riscv-v-spec/blob/master/vmem-format.adoc                               //
// valu (operaciones normales) - https://github.com/riscv/riscv-v-spec/blob/master/valu-format.adoc           //
// vcfg (operaciones de configuracion) - https://github.com/riscv/riscv-v-spec/blob/master/vcfg-format.adoc   //
// Tabla de instrucciones:                                                                                    //
// https://github.com/riscv/riscv-v-spec/blob/master/inst-table.adoc                                          //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`define LOAD_FP  7'b0000111   // Código de instrucción load
`define STORE_FP 7'b0100111   // Código de instrucción store
`define OP_V     7'b1010111   // Código de instrucción vectorial

`define OPIVV 3'b000          // Vector-Vector
`define OPFVV 3'b001          // Vector-Vector (float)
`define OPMVV 3'b010          // Vector-Vector (mult)
`define OPIVI 3'b011          // Vector-Inmediato
`define OPIVX 3'b100          // Vector-Escalar entero
`define OPFVF 3'b101          // Vector-Escalar float
`define OPMVX 3'b110          // Vector-Escalar (mult)


// Códigos para las distintas instrucciones posibles
`define VADD    6'b000000
`define VSUB    6'b000010
`define VAND    6'b001001
`define VOR     6'b001010
`define VXOR    6'b001011
`define VFSGNJ  6'b001000
`define VFSGNJN 6'b001001
`define VFSGNJX 6'b001010
`define VDIV    6'b100001
`define VREM    6'b100011
`define VMUL    6'b100101
`define VFDIV   6'b100000
`define VFMUL   6'b100100
`define VSLL    6'b100101
`define VSRL    6'b101000
`define VSRA    6'b101001
`define VMSNE   6'b011001
`define VMFNE   6'b011100
`define VMSEQ   6'b011000
`define VMFEQ   6'b011000
`define VMSLT   6'b011011
`define VMFLT   6'b011011

// Códigos de instrucciones especiales
`define VWXUNARY0 6'b010000
`define VFUNARY1  6'b010011
`define VMUNARY0  6'b010100

`define VFSQRT  5'b00000

module vect_instr_decoder #(
      parameter NUM_REGS = 32, 
      parameter NUM_ESC_REGS = 32, 
      parameter DATA_WIDTH = 32, 
      parameter MVL=32
    ) (
      input [31:0]                        instr,    // Instruccion codificada
      input                               valid_i,  // Valid de entrada
      output                              valid_o,  // Valid de salida
      
      // Señales de la instruccion decodificada
      output                              setvl,
      output                              add,
      output                              sub,
      output                              mul,
      output                              div,
      output                              rem,
      output                              sqrt,
      output                              addmul,
      output                              peq,
      output                              pne,
      output                              plt,
      output                              sll,
      output                              srl,
      output                              sra,
      output                              log_xor,
      output                              log_or,
      output                              log_and,
      output                              sgnj,
      output                              sgnjn,
      output                              sgnjx,
      output                              pxor,
      output                              por,
      output                              pand,
      output                              vid,
      output                              vcpop,
      output                              strided,
      output                              float,
      output [1:0]                        esc,
      output                              masked_op,
      output                              load,
      output                              iload,
      output                              store,
      output                              istore,
      output [bitwidth(NUM_REGS)-1:0]     src1,
      output [bitwidth(NUM_REGS)-1:0]     src2,
      output [bitwidth(NUM_ESC_REGS)-1:0] src1_esc,
      output [bitwidth(NUM_ESC_REGS)-1:0] src2_esc,
      output [bitwidth(NUM_REGS)-1:0]     dst,
      output [bitwidth(NUM_ESC_REGS)-1:0] dst_esc
    );
    
    // Wires para agrupar tipos de operaciones
    wire int1;  // Instrucciones de enteros (OPIVV, OPIVX, OPIVI)
    wire intm;  // Instrucciones de mult (OPMVV, OMPVX)
    wire unary; // Instrucciones especiales tipo UNARY
    
    // Conjunto de wires para representar los campos de cada tipo de instruccion
    // Hay algunos casos en los que los nombres de los campos de repiten,
    // por lo que se dejan comentados para que no generen conflictos
  
  ////////////////
  // WIRES LOAD //
  ////////////////
  
  // Unit-stride //
  
      wire [6:0]        funct7 = instr[6:0];      // Código global
      wire [4:0]            vd = instr[11:7];     // Vectorial destino
      wire [2:0]         width = instr[14:12];    // Anchura de dato de memoria (no se usa)
      wire [4:0]           rs1 = instr[19:15];    // Registro escalar fuente 1 (almacena la direccion base de memoria)
      wire [4:0]         lumop = instr[24:20];    // Configuracion de unit_stride (no se usa)
      wire                  vm = instr[25];       // Operación enmascarada
      wire [1:0]           mop = instr[27:26];    // Tipo de acceso a memoria
      wire                 mew = instr[28];       // - 
      wire                  nf = instr[31:29];    // -
      

  // Strided //
  
//    wire [6:0]        funct7 = instr[6:0];
//    wire [4:0]            vd = instr[11:7];
//    wire [2:0]         width = instr[14:12];
//    wire [4:0]           rs1 = instr[19:15];
      wire [4:0]           rs2 = instr[24:20];    // Registro escalar fuente 2 (almacena el stride)
//    wire                  vm = instr[25];
//    wire [1:0]           mop = instr[27:26];
//    wire                 mew = instr[28];
//    wire                  nf = instr[31:29];

  
  // Indexed //
  
//    wire [6:0]        funct7 = instr[6:0];
//    wire [4:0]            vd = instr[11:7];
//    wire [2:0]         width = instr[14:12];
//    wire [4:0]           rs1 = instr[19:15];
      wire [4:0]           vs2 = instr[24:20];    // Registro vectorial fuente 2 (almacena los índices)
//    wire                  vm = instr[25];
//    wire [1:0]           mop = instr[27:26];
//    wire                 mew = instr[28];
//    wire                  nf = instr[31:29];
    
    
  /////////////////
  // WIRES STORE //
  /////////////////
  
//   (mismos que en la load, pero vd se reemplaza por vs3)
      wire [4:0]            vs3 = instr[11:7];    // Registro vectorial fuente 3 (almacena los datos a escribir en memoria)


  ////////////////
  // WIRES VALU //
  ////////////////
  
//    wire [6:0]      funct7 = instr[6:0];
//    wire [4:0]          vd = instr[11:7];       // Registro destino (puede ser vd, vectorial; o rd, escalar; según la operación)
      wire [2:0]      funct3 = instr[14:12];      // Código de tipo de instruccion
      wire [4:0]         vs1 = instr[19:15];      // Registro fuente vectorial 1 (también puede ser rs1 si se usa un operando escalar)
//    wire [4:0]         vs2 = instr[20:24];      // Registro fuente vectorial 2
//    wire                vm = instr[25];
      wire [5:0]      funct6 = instr[31:26];      // Código de la operación a hacer
      
  ////////////////    
  // WIRES VCFG //
  ////////////////
// (solo el de la instruccion vsetvl

//    wire [6:0]      funct7 = instr[6:0];
      wire [4:0]          rd = instr[11:7];
//    wire [2:0]      funct3 = instr[14:12];
//    wire [4:0]         vs1 = instr[19:15];
//    wire [4:0]         vs2 = instr[20:24];
//    wire                vm = instr[25];
//    wire [5:0]      funct6 = instr[31:26];
    
    // WIRES AUXILIARES //
    wire mem_inst = funct7 == `LOAD_FP | funct7 == `STORE_FP; // Engloba instrucciones de memoria
    
    // Asignación de los wires de control //
    assign valid_o    = valid_i;                                                                                   // Valid
    assign int1       = ((funct3 == `OPIVV)   | (funct3 == `OPIVX)  | (funct3 == `OPIVI)) & (funct7 == `OP_V);     // Instruccion de enteros
    assign intm       = ((funct3 == `OPMVV)   | (funct3 == `OPMVX)) & (funct7 == `OP_V);                           // Instrucciones tipo mult/div
    assign unary      = (((funct6 == `VWXUNARY0 & funct3 == `OPMVV) |
                          (funct6 == `VFUNARY1  & funct3 == `OPFVV) |
                          (funct6 == `VMUNARY0  & funct3 == `OPMVV)) & (funct7 == `OP_V));                         // Instruccion unary
    assign float      = ((funct3 == `OPFVV)   | (funct3 == `OPFVF)) & (funct7 == `OP_V);                           // Instruccion float
    assign esc[0]     = 1'b0;                                                                                      // esc[0] se mantiene fijo a 0 (para hacer que el operando
                                                                                                                   // escalar fuente sea siempre el 1)
                                                                                                                   // Para implementar el otro orden (que el fuente escalar sea el 2)
                                                                                                                   // poner esc[0] = 1
    assign esc[1]     = ((funct3 == `OPIVX)   | (funct3 == `OPMVX)  | (funct3 == `OPFVF)) & ~mem_inst;             // Si operación con escalar, se activa esc[1]
                                                                                                                   // Se comprueba que no sea instruccion de memoria para que
                                                                                                                   // no haya conflicto con el campo "width"
    assign masked_op  = ~vm;                                                                                       // Operación enmascarada
    
    // Aqui simplemente es comprobar las señales que toquen para activar la instrucción correspondiente
    // Se comprueban segun convenga: int1, intm, float, funct3, funct7, vs1...
    // Para saber qué campos son necesarios según la instrucción, ver la tabla de instrucciones:
    // https://github.com/riscv/riscv-v-spec/blob/master/inst-table.adoc
    
    assign setvl        = (funct7 == `OP_V & funct3 == 3'b111);                             // vsetvl
    assign add          = (int1 | float) & (funct6 == `VADD);                               // vadd (vfadd si float = 1)
    assign sub          = (int1 | float) & (funct6 == `VSUB);                               // vsub (vfsub si float = 1)
    assign mul          = (intm & funct6 == `VMUL) | (float & funct6 == `VFMUL);            // vmul (vfmul si float = 1)
    assign div          = (intm & funct6 == `VDIV) | (float & funct6 == `VFDIV);            // vdiv (vfdiv si float = 1)
    assign rem          = (intm & funct6 == `VREM);                                         // vrem (no hay variante float)
    assign sqrt         = (funct6 == `VFUNARY1) & (funct3 == `OPFVV) & (vs1 == `VFSQRT);    // vfsqrt
    assign addmul       = 0;                                                                // No se implementa
    assign peq          = (int1 & funct6 == `VMSEQ) | (float & funct6 == `VMFEQ);           // vmseq (vmfeq si float = 1)
    assign pne          = (int1 & funct6 == `VMSNE) | (float & funct6 == `VMFNE);           // vmsne (vmfne si float = 1)
    assign plt          = (int1 & funct6 == `VMSLT) | (float & funct6 == `VMFLT);           // vmslt (vmflt si float = 1)
    assign sll          = int1  & (funct6 == `VSLL);                                        // vsll
    assign srl          = int1  & (funct6 == `VSRL);                                        // vsrl
    assign sra          = int1  & (funct6 == `VSRA);                                        // vsra
    assign log_xor      = int1  & (funct6 == `VXOR);                                        // vxor
    assign log_or       = int1  & (funct6 == `VOR);                                         // vor
    assign log_and      = int1  & (funct6 == `VAND);                                        // vand
    assign sgnj         = float & (funct6 == `VFSGNJ);                                      // vfsgnj
    assign sgnjn        = float & (funct6 == `VFSGNJN);                                     // vfsgnjn
    assign sgnjx        = float & (funct6 == `VFSGNJX);                                     // vfsgnjx
    // Estas al parecer no se encuentran en la tabla
    assign pxor         = 0;
    assign por          = 0;
    assign pand         = 0;
    //
    assign vid          = (vs1 == 5'b10001) & (funct6 == `VMUNARY0)  & (funct3 == `OPMVV) & (funct7 == `OP_V);  // vid
    assign vcpop        = (vs1 == 5'b10000) & (funct6 == `VWXUNARY0) & (funct3 == `OPMVV) & (funct7 == `OP_V);  // vcpop
    
    assign load         = (funct7 == `LOAD_FP)  & (mop[0] == 1'b0);                         // vload
    assign iload        = (funct7 == `LOAD_FP)  & (mop[0] == 1'b1);                         // vload (indexada)
    assign store        = (funct7 == `STORE_FP) & (mop[0] == 1'b0);                         // vstore
    assign istore       = (funct7 == `STORE_FP) & (mop[0] == 1'b1);                         // vstore (indexada)
    assign strided      = (mem_inst & mop == 2'b10);                                        // Indica acceso a memora regular no secuencial
    
    
    // Lógica de los fuentes (cambia un poco para adaptarse al resto del sistema)
    // src1, src2 y dst son los vectoriales, src1_esc, src2_esc y dst_esc son los escalares
    
    // Para src1:
    // Cuando es una store, el campo vs3 me dice de qué registro vectorial leer, yo ese registo lo reubico sobre src1: src1 = vs3
    // Si es una operación OP_V normal y no tiene fuente escalar: src1 = vs1
    // En cualquier otro caso, no se usa un fuente escalar por lo que lo pongo por defecto a 0
    // (realmente se puede poner a cualquier valor, porque en ese caso no se leerá)
    assign src1         = (funct7 == `STORE_FP)                      ? vs3 :
                          (~esc[1] & ~unary & ~mem_inst & ~setvl)    ? vs1 : 0;
    
    // Para src2:
    // Cuando es operación de memoria con acceso regular o operacion setvl, se pone a 0 porque no se usa
    // En cualquier otro caso: OP_V u operacion de memoria con acceso no regular, si que se usa y recibe el valor del campo vs2
    assign src2         = ((mem_inst & mop[0] == 1'b0) | setvl)      ? 0 : vs2;
    
    // Para src1_esc
    // Si es operación de memoria u OP_V con operando escalar, se usa y recibe el valor de rs1
    // Si es una operación setvl, toma el valor de rs2, esto es porque la implementación
    // para leer de un registro escalar en instruccion setvl está hecha para que lea el fuente 1,
    // pero en la memoria pone que en la codificación de la instrucción, se usa el fuente 2 
    // para indicar el registro del que coger el nuevo vlr, por ello aquí simplemente se mueve
    // ese rs2 al src1_esc
    
    assign src1_esc     = (esc[1] | mem_inst) ? rs1 : (setvl) ? rs2 : 0;
    
    // Para sr2_esc
    // Si es operación de memoria con acceso regular no secuencial, se usa (ya que se debe leer el stride) y recibe el valor de rs2
    assign src2_esc     = (mem_inst & (mop == 2'b10))                ? rs2 : 0;
    
    // Para dst
    // Mientras no sea una store ni vcpop ni setvl, se usa y recibe el valor del campo dst
    assign dst          = (funct7 != `STORE_FP & ~vcpop & ~setvl)    ? vd : 0;
    
    // Para dst_esc
    // Cuan la instrucción sea vcpop, se usa y recibe el valor del campo rd
    assign dst_esc      = (vcpop) ? rd : 0;                         // If vcpop, dst_esc acts as rd
    
    
   /////////////////////////////////////
   
   function integer log2(integer value);
   integer temp;
   begin
   temp = value-1;
   for (log2=0; temp>0; log2=log2+1)
   temp = temp>>1;
   end
   endfunction
   
   //////////////////////////////////////

   function integer bitwidth(integer value);
   begin                          
   if (value <= 1)
   bitwidth = 1;
   else
   bitwidth = log2(value);
   end
   endfunction
    
endmodule
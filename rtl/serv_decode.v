/*
 * serv_decode.v : SERV module decoding instruction word into control signals
 *
 * SPDX-FileCopyrightText: 2018 Olof Kindgren <olof@award-winning.me>
 * SPDX-License-Identifier: ISC
 */
`default_nettype none
module serv_decode
  #(parameter [0:0] PRE_REGISTER = 1,
    parameter [0:0] MDU = 0)
  (
   input wire        clk,
   //Input
   input wire [31:2] i_wb_rdt,
   input wire        i_wb_en,
   //To state
   output reg       o_sh_right,
   output reg       o_bne_or_bge,
   output reg       o_cond_branch,
   output reg       o_e_op,
   output reg       o_ebreak,
   output reg       o_branch_op,
   output reg       o_shift_op,
   output reg       o_rd_op,
   output reg       o_two_stage_op,
   output reg       o_dbus_en,
   //MDU
   output reg       o_mdu_op,
   //Extension
   output reg [2:0] o_ext_funct3,
   //To bufreg
   output reg       o_bufreg_rs1_en,
   output reg       o_bufreg_imm_en,
   output reg       o_bufreg_clr_lsb,
   output reg       o_bufreg_sh_signed,
   //To ctrl
   output reg       o_ctrl_jal_or_jalr,
   output reg       o_ctrl_utype,
   output reg       o_ctrl_pc_rel,
   output reg       o_ctrl_mret,
   //To alu
   output reg       o_alu_sub,
   output reg [1:0] o_alu_bool_op,
   output reg       o_alu_cmp_eq,
   output reg       o_alu_cmp_sig,
   output reg [2:0] o_alu_rd_sel,
   //To mem IF
   output reg       o_mem_signed,
   output reg       o_mem_word,
   output reg       o_mem_half,
   output reg       o_mem_cmd,
   //To CSR
   output reg       o_csr_en,
   output reg [1:0] o_csr_addr,
   output reg       o_csr_mstatus_en,
   output reg       o_csr_mie_en,
   output reg       o_csr_mcause_en,
   output reg [1:0] o_csr_source,
   output reg       o_csr_d_sel,
   output reg       o_csr_imm_en,
   output reg       o_mtval_pc,
   //To top
   output reg [3:0] o_immdec_ctrl,
   output reg [3:0] o_immdec_en,
   output reg       o_op_b_source,
   //To RF IF
   output reg       o_rd_mem_en,
   output reg       o_rd_csr_en,
   output reg       o_rd_alu_en);

   /* Instruction map

   RV32I

   3322222 22222 11111 111 11
   1098765 43210 98765 432 10987 6543210
   -------------------------------------
   iiiiiii iiiii iiiii iii rrrrr 0110111 LUI

   iiiiiii iiiii iiiii iii rrrrr 0010111 AUIPC

   iiiiiii iiiii iiiii iii rrrrr 1101111 JAL

   iiiiiii iiiii rrrrr 000 rrrrr 1100111 JALR

   iiiiiii rrrrr rrrrr 000 iiiii 1100011 BEQ
   iiiiiii rrrrr rrrrr 001 iiiii 1100011 BNE
   iiiiiii rrrrr rrrrr 100 iiiii 1100011 BLT
   iiiiiii rrrrr rrrrr 101 iiiii 1100011 BGE
   iiiiiii rrrrr rrrrr 110 iiiii 1100011 BLTU
   iiiiiii rrrrr rrrrr 111 iiiii 1100011 BGEU

   iiiiiii iiiii rrrrr 000 rrrrr 0000011 LB
   iiiiiii iiiii rrrrr 001 rrrrr 0000011 LH
   iiiiiii iiiii rrrrr 010 rrrrr 0000011 LW
   iiiiiii iiiii rrrrr 100 rrrrr 0000011 LBU
   iiiiiii iiiii rrrrr 101 rrrrr 0000011 LHU

   iiiiiii rrrrr rrrrr 000 iiiii 0100011 SB
   iiiiiii rrrrr rrrrr 001 iiiii 0100011 SH
   iiiiiii rrrrr rrrrr 010 iiiii 0100011 SW

   iiiiiii iiiii rrrrr 000 rrrrr 0010011 ADDI
   iiiiiii iiiii rrrrr 010 rrrrr 0010011 SLTI
   iiiiiii iiiii rrrrr 011 rrrrr 0010011 SLTIU
   iiiiiii iiiii rrrrr 100 rrrrr 0010011 XORI
   iiiiiii iiiii rrrrr 110 rrrrr 0010011 ORI
   iiiiiii iiiii rrrrr 111 rrrrr 0010011 ANDI
   0000000 sssss rrrrr 001 rrrrr 0010011 SLLI
   0000000 sssss rrrrr 101 rrrrr 0010011 SRLI
   0100000 sssss rrrrr 101 rrrrr 0010011 SRAI

   0000000 rrrrr rrrrr 000 rrrrr 0110011 ADD
   0100000 rrrrr rrrrr 000 rrrrr 0110011 SUB
   0000000 rrrrr rrrrr 001 rrrrr 0110011 SLL
   0000000 rrrrr rrrrr 010 rrrrr 0110011 SLT
   0000000 rrrrr rrrrr 011 rrrrr 0110011 SLTU
   0000000 rrrrr rrrrr 100 rrrrr 0110011 XOR
   0000000 rrrrr rrrrr 101 rrrrr 0110011 SRL
   0100000 rrrrr rrrrr 101 rrrrr 0110011 SRA
   0000000 rrrrr rrrrr 110 rrrrr 0110011 OR
   0000000 rrrrr rrrrr 111 rrrrr 0110011 AND

   0000000 00000 00000 000 00000 1110011 ECALL
   0000000 00001 00000 000 00000 1110011 EBREAK

   RV32M
   3322222 22222 11111 111 11
   1098765 43210 98765 432 10987 6543210
   -------------------------------------
   0000001 rrrrr rrrrr 000 rrrrr 0110011 MUL
   0000001 rrrrr rrrrr 001 rrrrr 0110011 MULH
   0000001 rrrrr rrrrr 010 rrrrr 0110011 MULHSU
   0000001 rrrrr rrrrr 011 rrrrr 0110011 MULHU
   0000001 rrrrr rrrrr 100 rrrrr 0110011 DIV
   0000001 rrrrr rrrrr 101 rrrrr 0110011 DIVU
   0000001 rrrrr rrrrr 110 rrrrr 0110011 REM
   0000001 rrrrr rrrrr 111 rrrrr 0110011 REMU

   Zicsr
   3322222 22222 11111 111 11
   1098765 43210 98765 432 10987 6543210
   -------------------------------------
   ccccccc ccccc rrrrr 001 rrrrr 1110011 CSRRW
   ccccccc ccccc rrrrr 010 rrrrr 1110011 CSRRS
   ccccccc ccccc rrrrr 011 rrrrr 1110011 CSRRC
   ccccccc ccccc iiiii 100 rrrrr 1110011 CSRRWI
   ccccccc ccccc iiiii 101 rrrrr 1110011 CSRRSI
   ccccccc ccccc iiiii 111 rrrrr 1110011 CSRRCI

   Zbb
   3322222 22222 11111 111 11
   1098765 43210 98765 432 10987 6543210
   -------------------------------------
   0100000 rrrrr rrrrr 100 rrrrr 0110011 XORN
   0100000 rrrrr rrrrr 110 rrrrr 0110011 ORN
   0100000 rrrrr rrrrr 111 rrrrr 0110011 ANDN
   0000101 rrrrr rrrrr 100 rrrrr 0110011 MIN
   0000101 rrrrr rrrrr 101 rrrrr 0110011 MINU
   0000101 rrrrr rrrrr 110 rrrrr 0110011 MAX
   0000101 rrrrr rrrrr 111 rrrrr 0110011 MAXU
   0000100 00000 rrrrr 100 rrrrr 0110011 ZEXT.H 
   0110000 rrrrr rrrrr 001 rrrrr 0110011 ROL
   0110000 rrrrr rrrrr 101 rrrrr 0110011 ROR

   0110000 00000 rrrrr 001 rrrrr 0010011 CLZ
   0110000 00001 rrrrr 001 rrrrr 0010011 CTZ
   0110000 00010 rrrrr 001 rrrrr 0010011 CPOP
   0110100 11000 rrrrr 101 rrrrr 0010011 REV8
   0110000 00100 rrrrr 001 rrrrr 0010011 SEXT.B
   0110000 00101 rrrrr 001 rrrrr 0010011 SEXT.H
   0110000 sssss rrrrr 101 rrrrr 0010011 RORI
   0010100 00111 rrrrr 101 rrrrr 0010011 ORC.B

   Use bits in decoding
   3322222 22222 11111 111 11
   1098765 43210 98765 432 10987 6543210
   -------------------------------------
   -x---xx --xxx ----- xxx ----- xxxxx--


   Decoders view of OP instructions

   3322222 22222 11111 111 11
   1098765 43210 98765 432 10987 6543210
   -------------------------------------
   -0----- ----- ----- 000 ----- 01100-- ADD
   -1----- ----- ----- 000 ----- 01100-- SUB
   -0----- ----- ----- 001 ----- 01100-- SLL
   -1----- ----- ----- 001 ----- 01100-- ROL
   ------- ----- ----- 010 ----- 01100-- SLT
   ------- ----- ----- 011 ----- 01100-- SLTU
   -0--0-- ----- ----- 100 ----- 01100-- XOR
   -0--1-0 ----- ----- 100 ----- 01100-- ZEXT.H	(Zbb, TODO)
   -0--1-1 ----- ----- 100 ----- 01100-- MIN	(Zbb, TODO)
   -1----- ----- ----- 100 ----- 01100-- XORN	(Zbb, TODO)
   -0----0 ----- ----- 101 ----- 01100-- SRL
   -0----1 ----- ----- 101 ----- 01100-- MINU	(Zbb, TODO
   -10---- ----- ----- 101 ----- 01100-- SRA
   -11---- ----- ----- 101 ----- 01100-- ROR	(Zbb, N/A)
   -0----0 ----- ----- 110 ----- 01100-- OR
   -0----1 ----- ----- 110 ----- 01100-- MAX	(Zbb, TODO)
   -1----- ----- ----- 110 ----- 01100-- ORN	(Zbb,TODO)
   -0----0 ----- ----- 111 ----- 01100-- AND
   -0----1 ----- ----- 111 ----- 01100-- MAXU	(Zbb, TODO)
   -1----- ----- ----- 111 ----- 01100-- ANDN	(Zbb, TODO)


   Decoders view on OP-IMM instructions
   3322222 22222 11111 111 11
   1098765 43210 98765 432 10987 6543210
   -------------------------------------
   ------- ----- ----- 000 ----- 00100-- ADDI
   -0----- ----- ----- 001 ----- 00100-- SLLI
   -1----- --000 ----- 001 ----- 00100-- CLZ	(Zbb, TODO
   -1----- --001 ----- 001 ----- 00100-- CTZ	(Zbb, TODO)
   -1----- --01- ----- 001 ----- 00100-- CPOP	(Zbb, N/A)
   -1----- --1-0 ----- 001 ----- 00100-- SEXT.B	(Zbb, TODO)
   -1----- --1-1 ----- 001 ----- 00100-- SEXT.H	(Zbb, TODO)
   ------- ----- ----- 010 ----- 00100-- SLTI
   ------- ----- ----- 011 ----- 00100-- SLTIU
   ------- ----- ----- 100 ----- 00100-- XORI
   -00---- ----- ----- 101 ----- 00100-- SRLI
   -01---- ----- ----- 101 ----- 00100-- ORC.B	(Zbb, N/A)
   -10---- ----- ----- 101 ----- 00100-- SRAI
   -11-1-- ----- ----- 101 ----- 00100-- REV8	(Zbb, N/A)
   -11-0-- ----- ----- 101 ----- 00100-- RORI	(Zbb, N/A)
   ------- ----- ----- 110 ----- 00100-- ORI
   ------- ----- ----- 111 ----- 00100-- ANDI
   */

   reg [4:0] opcode;
   reg [2:0] funct3;
   reg        op20;
   reg        op21;
   reg        op22;
   reg        op26;
   reg	      op27;
   reg	      op29;

   reg       imm25;
   reg       imm30;

   wire co_mdu_op     = MDU & (opcode == 5'b01100) & imm25;

   wire co_two_stage_op =
	~opcode[2] |
	(funct3[0] & ~funct3[1] & ~opcode[0] & ~opcode[4]) |
	(funct3[1] & ~funct3[2] & ~opcode[0] & ~opcode[4]) |
	co_mdu_op;
   wire co_shift_op = (opcode[2] & ~funct3[1]) & !co_mdu_op;
   wire co_branch_op = opcode[4];
   wire co_dbus_en    = ~opcode[2] & ~opcode[4];
   wire co_mtval_pc   = opcode[4];
   wire co_mem_word   = funct3[1];
   wire co_rd_alu_en  = !opcode[0] & opcode[2] & !opcode[4] & !co_mdu_op;
   wire co_rd_mem_en  = (!opcode[2] & !opcode[0]) | co_mdu_op;
   wire [2:0] co_ext_funct3 = funct3;

   //jal,branch =     imm
   //jalr       = rs1+imm
   //mem        = rs1+imm
   //shift      = rs1
   wire co_bufreg_rs1_en = !opcode[4] | (!opcode[1] & opcode[0]);
   wire co_bufreg_imm_en = !opcode[2];

   //Clear LSB of immediate for BRANCH and JAL ops
   //True for BRANCH and JAL
   //False for JALR/LOAD/STORE/OP/OPIMM?
   wire co_bufreg_clr_lsb = opcode[4] & ((opcode[1:0] == 2'b00) | (opcode[1:0] == 2'b11));

   //Conditional branch
   //True for BRANCH
   //False for JAL/JALR
   wire co_cond_branch = !opcode[0];

   wire co_ctrl_utype       = !opcode[4] & opcode[2] & opcode[0];
   wire co_ctrl_jal_or_jalr = opcode[4] & opcode[0];

   //PC-relative operations
   //True for jal, b* auipc, ebreak
   //False for jalr, lui
   wire co_ctrl_pc_rel = (opcode[2:0] == 3'b000)  |
                          (opcode[1:0] == 2'b11)  |
                          (opcode[4] & opcode[2]) & op20|
                          (opcode[4:3] == 2'b00);
   //Write to RD
   //True for OP-IMM, AUIPC, OP, LUI, SYSTEM, JALR, JAL, LOAD
   //False for STORE, BRANCH, MISC-MEM
   wire co_rd_op = (opcode[2] |
                     (!opcode[2] & opcode[4] & opcode[0]) |
                     (!opcode[2] & !opcode[3] & !opcode[0]));

   //
   //funct3
   //

   wire co_sh_right   = funct3[2];
   wire co_bne_or_bge = funct3[0];

   //Matches system ops except ecall/ebreak/mret
   wire csr_op = opcode[4] & opcode[2] & (|funct3);


   //op20
   wire co_ebreak = op20;


   //opcode & funct3 & op21

   wire co_ctrl_mret = opcode[4] & opcode[2] & op21 & !(|funct3);
   //Matches system opcodes except CSR accesses (funct3 == 0)
   //and mret (!op21)
   wire co_e_op = opcode[4] & opcode[2] & !op21 & !(|funct3);

   //opcode & funct3 & imm30

   wire co_bufreg_sh_signed = imm30;

   /*
    True for sub, b*, slt*
    False for add*
    op    opcode f3  i30
    b*    11000  xxx x   t
    addi  00100  000 x   f
    slt*  0x100  01x x   t
    add   01100  000 0   f
    sub   01100  000 1   t
    */
   wire co_alu_sub = funct3[1] | funct3[0] | (opcode[3] & imm30) | opcode[4];

   /*
    Bits 26, 22, 21 and 20 are enough to uniquely identify the eight supported CSR regs
    mtvec, mscratch, mepc and mtval are stored externally (normally in the RF) and are
    treated differently from mstatus, mie and mcause which are stored in serv_csr.

    The former get a 2-bit address as seen below while the latter get a
    one-hot enable signal each.

    Hex|2 222|Reg     |csr
    adr|6 210|name    |addr
    ---|-----|--------|----
    300|0_000|mstatus | xx
    304|0_100|mie     | xx
    305|0_101|mtvec   | 01
    340|1_000|mscratch| 00
    341|1_001|mepc    | 10
    342|1_010|mcause  | xx
    343|1_011|mtval   | 11

    */

   //true  for mtvec,mscratch,mepc and mtval
   //false for mstatus, mie, mcause
   wire csr_valid = op20 | (op26 & !op21);

   wire co_rd_csr_en = csr_op;

   wire co_csr_en         = csr_op & csr_valid;
   wire co_csr_mstatus_en = csr_op & !op26 & !op22 & !op20;
   wire co_csr_mie_en     = csr_op & !op26 &  op22 & !op20;
   wire co_csr_mcause_en  = csr_op         &  op21 & !op20;

   wire [1:0] co_csr_source = funct3[1:0];
   wire co_csr_d_sel = funct3[2];
   wire co_csr_imm_en = opcode[4] & opcode[2] & funct3[2];
   wire [1:0] co_csr_addr = {op26 & op20, !op26 | op21};

   wire co_alu_cmp_eq = funct3[2:1] == 2'b00;

   wire co_alu_cmp_sig = ~((funct3[0] & funct3[1]) | (funct3[1] & funct3[2]));

   wire co_mem_cmd  = opcode[3];
   wire co_mem_signed = ~funct3[2];
   wire co_mem_half   = funct3[0];

   wire [1:0] co_alu_bool_op = funct3[1:0];

   wire [3:0] co_immdec_ctrl;
   //True for S (STORE) or B (BRANCH) type instructions
   //False for J type instructions
   assign co_immdec_ctrl[0] = opcode[3:0] == 4'b1000;
   //True for OP-IMM, LOAD, STORE, JALR  (I S)
   //False for LUI, AUIPC, JAL           (U J)
   assign co_immdec_ctrl[1] = (opcode[1:0] == 2'b00) | (opcode[2:1] == 2'b00);
   assign co_immdec_ctrl[2] = opcode[4] & !opcode[0];
   assign co_immdec_ctrl[3] = opcode[4];

   wire [3:0] co_immdec_en;
   assign co_immdec_en[3] = opcode[4] | opcode[3] | opcode[2] | !opcode[0];                 //B I J S U
   assign co_immdec_en[2] = (opcode[4] & opcode[2]) | !opcode[3] | opcode[0];               //  I J   U
   assign co_immdec_en[1] = (opcode[2:1] == 2'b01) | (opcode[2] & opcode[0]) | co_csr_imm_en;//    J   U
   assign co_immdec_en[0] = ~co_rd_op;                                                       //B     S

   wire [2:0] co_alu_rd_sel;
   assign co_alu_rd_sel[0] = (funct3 == 3'b000); // Add/sub
   assign co_alu_rd_sel[1] = (funct3[2:1] == 2'b01); //SLT*
   assign co_alu_rd_sel[2] = funct3[2]; //Bool

   //0 (OP_B_SOURCE_IMM) when OPIMM
   //1 (OP_B_SOURCE_RS2) when BRANCH or OP
   wire co_op_b_source = opcode[3];

   generate
      if (PRE_REGISTER) begin : gen_pre_register

         always @(posedge clk) begin
            if (i_wb_en) begin
               funct3 <= i_wb_rdt[14:12];
               imm30  <= i_wb_rdt[30];
               imm25  <= i_wb_rdt[25];
               opcode <= i_wb_rdt[6:2];
               op20   <= i_wb_rdt[20];
               op21   <= i_wb_rdt[21];
               op22   <= i_wb_rdt[22];
               op26   <= i_wb_rdt[26];
	       op27   <= i_wb_rdt[27];
	       op29   <= i_wb_rdt[29];
            end
         end

         always @(*) begin
            o_sh_right         = co_sh_right;
            o_bne_or_bge       = co_bne_or_bge;
            o_cond_branch      = co_cond_branch;
            o_dbus_en          = co_dbus_en;
            o_mtval_pc         = co_mtval_pc;
	    o_two_stage_op     = co_two_stage_op;
            o_e_op             = co_e_op;
            o_ebreak           = co_ebreak;
            o_branch_op        = co_branch_op;
            o_shift_op         = co_shift_op;
            o_rd_op            = co_rd_op;
            o_mdu_op           = co_mdu_op;
            o_ext_funct3       = co_ext_funct3;
            o_bufreg_rs1_en    = co_bufreg_rs1_en;
            o_bufreg_imm_en    = co_bufreg_imm_en;
            o_bufreg_clr_lsb   = co_bufreg_clr_lsb;
            o_bufreg_sh_signed = co_bufreg_sh_signed;
            o_ctrl_jal_or_jalr = co_ctrl_jal_or_jalr;
            o_ctrl_utype       = co_ctrl_utype;
            o_ctrl_pc_rel      = co_ctrl_pc_rel;
            o_ctrl_mret        = co_ctrl_mret;
            o_alu_sub          = co_alu_sub;
            o_alu_bool_op      = co_alu_bool_op;
            o_alu_cmp_eq       = co_alu_cmp_eq;
            o_alu_cmp_sig      = co_alu_cmp_sig;
            o_alu_rd_sel       = co_alu_rd_sel;
            o_mem_signed       = co_mem_signed;
            o_mem_word         = co_mem_word;
            o_mem_half         = co_mem_half;
            o_mem_cmd          = co_mem_cmd;
            o_csr_en           = co_csr_en;
            o_csr_addr         = co_csr_addr;
            o_csr_mstatus_en   = co_csr_mstatus_en;
            o_csr_mie_en       = co_csr_mie_en;
            o_csr_mcause_en    = co_csr_mcause_en;
            o_csr_source       = co_csr_source;
            o_csr_d_sel        = co_csr_d_sel;
            o_csr_imm_en       = co_csr_imm_en;
            o_immdec_ctrl      = co_immdec_ctrl;
            o_immdec_en        = co_immdec_en;
            o_op_b_source      = co_op_b_source;
            o_rd_csr_en        = co_rd_csr_en;
            o_rd_alu_en        = co_rd_alu_en;
            o_rd_mem_en        = co_rd_mem_en;
         end

      end else begin : gen_post_register

         always @(*) begin
            funct3  = i_wb_rdt[14:12];
            imm30   = i_wb_rdt[30];
            imm25   = i_wb_rdt[25];
            opcode  = i_wb_rdt[6:2];
            op20    = i_wb_rdt[20];
            op21    = i_wb_rdt[21];
            op22    = i_wb_rdt[22];
            op26    = i_wb_rdt[26];
	    op27    = i_wb_rdt[27];
	    op29    = i_wb_rdt[29];
         end

         always @(posedge clk) begin
            if (i_wb_en) begin
               o_sh_right         <= co_sh_right;
               o_bne_or_bge       <= co_bne_or_bge;
               o_cond_branch      <= co_cond_branch;
               o_e_op             <= co_e_op;
               o_ebreak           <= co_ebreak;
               o_two_stage_op     <= co_two_stage_op;
               o_dbus_en          <= co_dbus_en;
               o_mtval_pc         <= co_mtval_pc;
               o_branch_op        <= co_branch_op;
               o_shift_op         <= co_shift_op;
               o_rd_op            <= co_rd_op;
               o_mdu_op           <= co_mdu_op;
               o_ext_funct3       <= co_ext_funct3;
               o_bufreg_rs1_en    <= co_bufreg_rs1_en;
               o_bufreg_imm_en    <= co_bufreg_imm_en;
               o_bufreg_clr_lsb   <= co_bufreg_clr_lsb;
               o_bufreg_sh_signed <= co_bufreg_sh_signed;
               o_ctrl_jal_or_jalr <= co_ctrl_jal_or_jalr;
               o_ctrl_utype       <= co_ctrl_utype;
               o_ctrl_pc_rel      <= co_ctrl_pc_rel;
               o_ctrl_mret        <= co_ctrl_mret;
               o_alu_sub          <= co_alu_sub;
               o_alu_bool_op      <= co_alu_bool_op;
               o_alu_cmp_eq       <= co_alu_cmp_eq;
               o_alu_cmp_sig      <= co_alu_cmp_sig;
               o_alu_rd_sel       <= co_alu_rd_sel;
               o_mem_signed       <= co_mem_signed;
               o_mem_word         <= co_mem_word;
               o_mem_half         <= co_mem_half;
               o_mem_cmd          <= co_mem_cmd;
               o_csr_en           <= co_csr_en;
               o_csr_addr         <= co_csr_addr;
               o_csr_mstatus_en   <= co_csr_mstatus_en;
               o_csr_mie_en       <= co_csr_mie_en;
               o_csr_mcause_en    <= co_csr_mcause_en;
               o_csr_source       <= co_csr_source;
               o_csr_d_sel        <= co_csr_d_sel;
               o_csr_imm_en       <= co_csr_imm_en;
               o_immdec_ctrl      <= co_immdec_ctrl;
               o_immdec_en        <= co_immdec_en;
               o_op_b_source      <= co_op_b_source;
               o_rd_csr_en        <= co_rd_csr_en;
               o_rd_alu_en        <= co_rd_alu_en;
               o_rd_mem_en        <= co_rd_mem_en;
            end
         end

      end
   endgenerate

endmodule

//-----------------------------------------------------------------------------
// Title         : Package uCode Decoder
//-----------------------------------------------------------------------------
// File          : pkg_ucode_decoder.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 10.10.2018
//-----------------------------------------------------------------------------
// Description :
// Contains the definition of the opcodes.
//-----------------------------------------------------------------------------
// SPDX-License-Identifier: SHL-0.51
// Copyright (C) 2018-2021 ETH Zurich, University of Bologna
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//-----------------------------------------------------------------------------


package pkg_ucode_decoder;

  //------------------------- OP-Codes -------------------------
  typedef enum logic [4:0] {
               OP_NOP,            //noargs
               OP_INTRPT,         //type3, max_idx+1, max_distance+1
               OP_JMP,            //type2, target
               OP_CLR_OFFSET,     //noargs
               OP_INC_OFFSET,     //noargs
               OP_DEC_OFFSET,     //noargs
               OP_ACK_SAMPLE,     //noargs
               OP_LOOP_SETUP0,    //type1, iterations, end_addr (inclusive) #Innermost loop
               OP_LOOP_SETUP1,    //type1, iterations, end_addr
               OP_LOOP_SETUP2,    //type1, iterations, end_addr (inclusive) #Outermost loop
               OP_STORE_BNDL_CTX, //type2, dst_start_idx
               OP_LOAD_BNDL_CTX,  //type2, src_start_idx
               OP_ADD_BNDL_CTX,   //type2, src_start_idx
               OP_AM_SEARCH,      //type1, -, search end idx
               OP_MIX_EXT,        //type2, length
               OP_MIX_IMMEDIATE,  //type3, lenght, immediate
               OP_MIX_OFFSET,     //noargs
               OP_SET_MAN_VALUE   //type2, value
               } opcode_t;

  typedef struct packed {
    opcode_t     opcode;
    logic [9:0]  operand_a;
    logic [9:0]  operand_b;
  } type1_t;

  typedef struct packed {
    opcode_t     opcode;
    logic [19:0] operand;
  } type2_t;

  typedef struct packed {
    opcode_t     opcode;
    logic [3:0]  length;
    logic [15:0] operand;
  } type3_t;


  typedef union  packed {
    type1_t      type1_instr;
    type2_t      type2_instr;
    type3_t      type3_instr;
  } risc_instr_t;


  typedef struct packed                      {
    pkg_hd_encoder::input_sel_t     enc_input_sel;
    logic                           man_en;
    pkg_hd_encoder::man_value_sel_t man_value_sel;
    logic                           mixer_en;
    logic                           mixer_inverse;
    logic                           mixer_perm_sel;
    pkg_hd_unit::operand_sel_e      hd_op_sel;
    logic                           bundler_en;
    logic                           bundler_rst;
    logic                           write_back_en;
    logic [5:0]                     vector_read_idx;
    logic [5:0]                     vector_write_idx;
  } nisc_instr_t;

  typedef enum                      logic[0:0] {RISC = 1'b0,NISC = 1'b1} instr_class_t;

  typedef struct                    packed                      {
    instr_class_t                   instr_class;
    union                           packed {
      risc_instr_t                  risc_instr;
      nisc_instr_t                  nisc_instr;
    } instruction;
  } instruction_t;


  localparam INSTRUCTION_WIDTH = $bits(instruction_t);


endpackage : pkg_ucode_decoder

//-----------------------------------------------------------------------------
// Title         : Config Unit
//-----------------------------------------------------------------------------
// File          : config_unit.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 10.10.2018
//-----------------------------------------------------------------------------
// Description :
// The Config Unit provides an interface to read and write to registers in the
// uCode sequencer and to access the hd_memory word wise.
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


module config_unit
  import pkg_common::*;

  import pkg_memory_mapping::*;
  import pkg_ucode_sequencer::*;
  import pkg_ucode_decoder::instruction_t;
  import pkg_ucode_decoder::INSTRUCTION_WIDTH;
  (
   input logic                        clk_i,
   input logic                        rst_ni,
   //--------------------- Config Interface ---------------------
   input logic                        cfg_req_i,
   output logic                       cfg_gnt_o,
   input logic                        cfg_wen_i,
   input cfg_addr_t                   cfg_addr_i,
   input word_t                       cfg_wdata_i,
   output word_t                      cfg_rdata_o,
   output logic                       cfg_rvalid_o,
   //--------------------- Register Read/Write Signals ---------------------
   //PC HW loop module
   output logic                       pc_we_o,
   input im_addr_t                    pc_rdata_i,
   output im_addr_t                   pc_wdata_o,

   //HD-memory
   output logic                       hd_mem_req_o,
   output logic                       hd_mem_we_o,
   output pkg_hd_memory::write_mode_t hd_mem_write_mode_o,
   output addr_t                      hd_mem_addr_o,
   input word_t                       hd_mem_word_i,
   output word_t                      hd_mem_word_o,

   //Instruction Memory
   output logic                       im_req_o,
   output logic                       im_we_o,
   output im_addr_t                   im_addr_o,
   input instruction_t                im_data_i,
   output instruction_t               im_data_o,

   //Offset Cntr
   output logic                       offset_cntr_we_o,
   input offset_t                     offset_cntr_i,
   output offset_t                    offset_cntr_o,

   //Internal MAN value
   output logic                       man_value_reg_we_o,
   input man_value_t                  man_value_reg_i,
   output man_value_t                 man_value_reg_o,

   //Decoder Enable Flag
   output logic                       dec_en_flag_we_o,
   input logic                        dec_en_flag_i,
   output logic                       dec_en_flag_o,

   //Next instruction reg
   output logic                       nxt_instr_reg_we_o,
   input instruction_t                nxt_instr_reg_i,
   output instruction_t               nxt_instr_reg_o,

   //Result Reg (read only)
   input vector_idx_t                 result_reg_idx_i,
   input hamming_distance_t           result_reg_distance_i,

   //Host interrupt
   output logic                       host_clr_intr_o,
   input logic                        host_intr_i
   );

  //--------------------- Internal Signals ---------------------
  //Output register
  word_t                              rdata_d, rdata_q;
  logic                               rvalid_d, rvalid_q;

  //Helper signals
  logic [15:12]                       cfg_reg_base_addr;
  logic [11:0]                        cfg_reg_addr;

  //------------------- Constant assignments -------------------
  assign cfg_rdata_o = rdata_q;
  assign cfg_rvalid_o = rvalid_q;

  assign cfg_reg_base_addr = cfg_addr_i[15:12]; // The remaining bits in the address
  assign cfg_reg_addr = cfg_addr_i[11:0]; //8 bits starting after cfg_device_base_addr



  always_comb
    begin
      //------------------- Default Assignments -------------------
      //Config interface
      cfg_gnt_o             = 1'b0;
      rdata_d               = 'X;
      rvalid_d              = 1'b0;

      //PC HW loop module
      pc_we_o               = 1'b0;
      pc_wdata_o            = 'X;

      //HD-memory
      hd_mem_req_o          = 1'b0;
      hd_mem_we_o           = 1'b0;
      hd_mem_write_mode_o   = pkg_hd_memory::WordMode;
      hd_mem_addr_o         = 'X;
      hd_mem_word_o         = 'X;

      //Instruction Memory
      im_req_o              = 1'b0;
      im_we_o               = 1'b0;
      im_addr_o             = 'X;
      im_data_o             = instruction_t'(cfg_wdata_i[INSTRUCTION_WIDTH-1:0]);

      //Offset Cntr
      offset_cntr_we_o      = 1'b0;
      offset_cntr_o         = 'X;

      //Internal MAN value
      man_value_reg_we_o    = 1'b0;
      man_value_reg_o       = 'X;

      //Decoder Enable Flag
      dec_en_flag_we_o      = 1'b0;
      dec_en_flag_o         = 'X;

      //Next instruction reg
      nxt_instr_reg_o       = instruction_t'('X);
      nxt_instr_reg_we_o    = 1'b0;

      //Host interrupt
      host_clr_intr_o       = 1'b0;

      if (cfg_req_i) begin
        //Decode address
        unique case (cfg_reg_base_addr)
          PC_BASE_ADDR: begin
            cfg_gnt_o = 1'b1;
            if (cfg_reg_addr == PC_REG) begin
              if (!cfg_wen_i) begin
                //Write request
                pc_we_o    = 1'b1;
                pc_wdata_o = cfg_wdata_i[IM_ADDR_WIDTH-1:0];
              end else begin
                //Read request
                rdata_d  = pc_rdata_i;
                rvalid_d = 1'b1;
              end
            end else begin // if (cfg_reg_addr == PC_REG)
              cfg_gnt_o = 1'b1;
              if (cfg_wen_i) begin
                rdata_d = 32'hdeadda7a;
                rvalid_d = 1'b1;
              end
              $display("Illegal debug address: %h", cfg_addr_i);
            end
          end

          HD_MEM_BASE_ADDR: begin
            cfg_gnt_o = 1'b1;
            if (!cfg_wen_i) begin
              hd_mem_req_o  = 1'b1;
              hd_mem_we_o   = 1'b1;
              hd_mem_addr_o = addr_t'(cfg_addr_i[WORD_ADDR_WIDTH-1+2:2]);
              hd_mem_word_o = cfg_wdata_i[WORD_WIDTH-1:0];
            end else begin
              hd_mem_req_o  = 1'b1;
              hd_mem_addr_o = addr_t'(cfg_addr_i[WORD_ADDR_WIDTH-1+2:2]);
              rdata_d       = hd_mem_word_i;
              rvalid_d      = 1'b1;
            end
          end

          IM_BASE_ADDR: begin
            cfg_gnt_o = 1'b1;
            if (!cfg_wen_i) begin
              im_req_o  = 1'b1;
              im_we_o   = 1'b1;
              im_addr_o = cfg_addr_i[IM_ADDR_WIDTH-1+2:2];
              im_data_o = instruction_t'(cfg_wdata_i[INSTRUCTION_WIDTH-1:0]);
            end else begin
              im_req_o  = 1'b1;
              im_addr_o = cfg_addr_i[IM_ADDR_WIDTH-1+2:2];
              rdata_d   = im_data_i;
              rvalid_d  = 1'b1;
            end
          end

          OFFSET_CNTR_BASE_ADDR: begin
            if (cfg_reg_addr == OFFSET_CNTR_REG) begin
              cfg_gnt_o = 1'b1;
              if (!cfg_wen_i) begin
                offset_cntr_we_o = 1'b1;
                offset_cntr_o    = cfg_wdata_i[SHARED_MEM_STRIDE_WIDTH-1:0];
              end else begin
                rdata_d  = offset_cntr_i;
                rvalid_d = 1'b1;
              end
            end else begin
              cfg_gnt_o = 1'b1;
              if (cfg_wen_i) begin
                rdata_d = 32'hdeadda7a;
                rvalid_d = 1'b1;
              end
              $display("Illegal debug address: %h", cfg_addr_i);
            end
          end

          INT_MAN_BASE_ADDR: begin
            if (cfg_reg_addr == INT_MAN_REG) begin
              cfg_gnt_o = 1'b1;
              if (!cfg_wen_i) begin
                man_value_reg_we_o = 1'b1;
                man_value_reg_o    = cfg_wdata_i[SHARED_MEM_STRIDE_WIDTH-1:0];
              end else begin
                rdata_d  = man_value_reg_i;
                rvalid_d = 1'b1;
              end
            end else begin
              cfg_gnt_o = 1'b1;
              if (cfg_wen_i) begin
                rdata_d = 32'hdeadda7a;
                rvalid_d = 1'b1;
              end
              $display("Illegal debug address: %h", cfg_addr_i);
            end
          end

          DEC_EN_BASE_ADDR: begin
            if (cfg_reg_addr == DEC_EN_REG) begin
              cfg_gnt_o = 1'b1;
              if (!cfg_wen_i) begin
                dec_en_flag_we_o = 1'b1;
                dec_en_flag_o    = cfg_wdata_i[0];
              end else begin
                rdata_d  = dec_en_flag_i;
                rvalid_d = 1'b1;
              end
            end else begin
              cfg_gnt_o = 1'b1;
              if (cfg_wen_i) begin
                rdata_d = 32'hdeadda7a;
                rvalid_d = 1'b1;
              end
              $display("Illegal debug address: %h", cfg_addr_i);
            end
          end

          NXT_INSTR_BASE_ADDR: begin
            if (cfg_reg_addr == NXT_INSTR_REG) begin
              cfg_gnt_o = 1'b1;
              if (!cfg_wen_i) begin
                nxt_instr_reg_we_o = 1'b1;
                nxt_instr_reg_o    = instruction_t'(cfg_wdata_i[INSTRUCTION_WIDTH-1:0]);
              end else begin
                rdata_d  = nxt_instr_reg_i;
                rvalid_d = 1'b1;
              end
            end else begin
              cfg_gnt_o = 1'b1;
              if (cfg_wen_i) begin
                rdata_d = 32'hdeadda7a;
                rvalid_d = 1'b1;
              end
              $display("Illegal debug address: %h", cfg_addr_i);
            end
          end

          RESULT_REG_BASE_ADDR: begin
            if (cfg_reg_addr == RESULT_REG_IDX) begin
              cfg_gnt_o                             = 1'b1;
              rdata_d                               = '0;
              rdata_d[VECTOR_IDX_WIDTH-1:0]         = result_reg_idx_i;
              rvalid_d                              = 1'b1;
            end else if (cfg_reg_addr == RESULT_REG_DISTANCE) begin
              cfg_gnt_o                           = 1'b1;
              rdata_d                             = '0;
              rdata_d[HAMMING_DISTANCE_WIDTH-1:0] = result_reg_distance_i;
              rvalid_d                            = 1'b1;
            end else begin
              cfg_gnt_o = 1'b1;
              if (cfg_wen_i) begin
                rdata_d = 32'hdeadda7a;
                rvalid_d = 1'b1;
              end
              $display("Illegal debug address: %h", cfg_addr_i);
            end
          end

          INTERRUPT_REG_BASE_ADDR: begin
            if (cfg_reg_addr == INTERRUPT_REG_IDX) begin
              cfg_gnt_o = 1'b1;
              if (!cfg_wen_i) begin
                //Write request. Assert the clear interrupt line regardless
                //of the write data
                host_clr_intr_o = 1'b1;
              end else begin
                //Read request. Send back current value of host_intr_o
                rdata_d = '0;
                rdata_d[0]  = host_intr_i;
                rvalid_d = 1'b1;
              end
            end else begin // if (cfg_reg_addr == INTERRUPT_REG_IDX)
              cfg_gnt_o = 1'b1;
              if (cfg_wen_i) begin
                rdata_d = 32'hdeadda7a;
                rvalid_d = 1'b1;
              end
              $display("Illegal debug address: %h", cfg_addr_i);
            end
          end // case: INTERRUPT_REG_BASE_ADDR

          default: begin
            cfg_gnt_o = 1'b1;
            if (cfg_wen_i) begin
              rdata_d = 32'hdeadda7a;
              rvalid_d = 1'b1;
            end
            $display("Illegal debug address: %h", cfg_addr_i);
          end
        endcase
      end
    end

  always_ff @(posedge clk_i, negedge rst_ni)
    begin
      if (!rst_ni) begin
        rvalid_q <= '0;
        rdata_q  <= '0;
      end else begin
        rvalid_q <= rvalid_d;
        rdata_q  <= rdata_d;
      end
    end
endmodule : config_unit

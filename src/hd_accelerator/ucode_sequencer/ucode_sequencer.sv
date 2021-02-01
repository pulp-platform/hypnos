//-----------------------------------------------------------------------------
// Title         : ucode Sequencer
//-----------------------------------------------------------------------------
// File          : ucode_sequncer.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 08.10.2018
//-----------------------------------------------------------------------------
// Description :
// The ucode sequencer orchestrates the whole HD-accelerator according to the ucode
// stored in its instruction memory.
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

module ucode_sequencer
  import pkg_common::*;
  import pkg_ucode_sequencer::*;
  (
    input logic                            clk_i,
    input logic                            rst_ni,
    //-------------------- HD-memory Signals --------------------
    output logic                           hd_mem_we_o,
    output pkg_hd_memory::write_mode_t     hd_mem_write_mode_o,
    output addr_t                          hd_mem_read_addr_o,
    output addr_t                          hd_mem_write_addr_o,
    input word_t                           hd_mem_word_i,
    output word_t                          hd_mem_word_o,
    output logic                           hd_mem_am_search_start_o,
    output logic                           hd_mem_am_search_stall_o,
    output vector_idx_t                    hd_mem_am_search_end_idx_o,
    input logic                            hd_mem_am_search_valid_i,
    input logic                            hd_mem_am_search_is_min_i,
    input vector_idx_t                     hd_mem_am_search_result_idx_i,
    input hamming_distance_t               hd_mem_am_search_distance_i,

    //-------------------- HD-encoder Signals --------------------
    output pkg_hd_encoder::input_sel_t     enc_input_sel_o,
    output logic                           enc_man_en_o,
    output pkg_hd_encoder::man_value_sel_t enc_man_value_sel_o,
    output man_value_t                     enc_int_man_value_o,
    output logic                           enc_mixer_en_o,
    output logic                           enc_mixer_inverse_o,
    output logic                           enc_mixer_perm_sel_o,
    output pkg_hd_unit::operand_sel_e      enc_op_sel_o,
    output logic                           enc_bundle_cntr_en_o,
    output logic                           enc_bundle_cntr_rst_o,
    output pkg_hd_unit::bundle_ctx_idx_t   enc_bundle_ctx_idx_o,
    output logic                           enc_bundle_ctx_we_o,
    output logic                           enc_bundle_ctx_add_o,
    //----------------- External Input Signal -----------------
    input logic [PREPROC_DATA_WIDTH-1:0]   idata_i,
    input logic                            idata_valid_i,
    output logic                           idata_switch_channel_o,
    output logic                           idata_ack_sample_o,
    //------------------ Host Interrupt Signals ------------------
    output logic                           host_intr_o,
    //--------------------- Configuration Interface ---------------------
    input logic                            cfg_req_i,
    output logic                           cfg_gnt_o,
    input logic                            cfg_wen_i,
    input pkg_memory_mapping::cfg_addr_t   cfg_addr_i,
    input word_t                           cfg_wdata_i,
    output word_t                          cfg_rdata_o,
    output logic                           cfg_rvalid_o
    );

  localparam bit                          IS_FOLDED = ROWS_PER_HDVECT > 1;

  //--------------------- Internal Registers ---------------------
  pkg_ucode_decoder::instruction_t         current_instruction_d,       current_instruction_q;
  logic                                    current_instruction_valid_d, current_instruction_valid_q;

  //hd_memory write port register
  logic                                    hd_mem_we_d,         hd_mem_we_q;
  addr_t                                   hd_mem_write_addr_d, hd_mem_write_addr_q;
  pkg_hd_memory::write_mode_t              hd_mem_write_mode_d, hd_mem_write_mode_q;
  word_t                                   hd_mem_word_wdata_d, hd_mem_word_wdata_q;

  //Offset counter
  offset_t                                 offset_cntr_d, offset_cntr_q;

  //Internal MAN value
  man_value_t                              man_value_reg_d, man_value_reg_q;

  //Decoder Enable Register
  logic                                    dec_en_flag_d, dec_en_flag_q;

  //--------------------- Internal Signals ---------------------
  //Instruction Memory
  im_addr_t                                im_addr;
  pkg_ucode_decoder::instruction_t         im_rdata;

  //Program Counter/HW loop engine
  logic                                    pc_we;
  logic                                    pc_en;
  im_addr_t                                pc_wdata;
  im_addr_t                                pc_rdata;

  //Instruction Decoder
  logic                                    dec_ready;
  logic                                    dec_pc_we;
  logic                                    dec_flush_pipeline;
  im_addr_t                                dec_pc_wdata;
  logic                                    dec_pc_hwl_we;
  logic [HWL_SEL_WIDTH-1:0]                dec_pc_hwl_sel;
  im_addr_t                                dec_pc_hwl_end_addr;
  hwl_iterations_t                         dec_pc_hwl_iterations;
  logic                                    dec_hd_mem_we;
  pkg_hd_memory::write_mode_t              dec_hd_mem_write_mode;
  vector_idx_t                             dec_hd_mem_vector_read_idx;
  vector_idx_t                             dec_hd_mem_vector_write_idx;
  logic                                    dec_offset_cntr_clr;
  logic                                    dec_offset_cntr_en;
  logic                                    dec_offset_cntr_dir;
  logic                                    dec_man_value_reg_we;
  man_value_t                              dec_man_value_reg;
  vector_idx_t                             dec_cfg_result_reg_idx;
  hamming_distance_t                       dec_cfg_result_reg_distance;
   logic                                   dec_host_intr;

  //Config Unit
  logic                                    cfg_pc_we;
  im_addr_t                                cfg_pc_wdata;
  logic                                    cfg_hd_mem_req;
  logic                                    cfg_hd_mem_we;
  pkg_hd_memory::write_mode_t              cfg_hd_mem_write_mode;
  addr_t                                   cfg_hd_mem_addr;
  logic                                    cfg_im_req;
  logic                                    cfg_im_we;
  im_addr_t                                cfg_im_addr;
  pkg_ucode_decoder::instruction_t         cfg_im_wdata;
  logic                                    cfg_offset_cntr_we;
  offset_t                                 cfg_offset_wdata;
  logic                                    cfg_man_value_reg_we;
  man_value_t                              cfg_man_value_reg_wdata;
  logic                                    cfg_dec_en_flag_we;
  logic                                    cfg_dec_en_flag;
  logic                                    cfg_nxt_instr_we;
  pkg_ucode_decoder::instruction_t         cfg_nxt_instr;
   logic                                   cfg_dec_host_clr_intr;


  //----------------------- Assignments -----------------------
  //Current Instruction Reg
  always_comb begin
    if (cfg_nxt_instr_we) begin
      current_instruction_d = cfg_nxt_instr;
    end  else if (dec_en_flag_q && dec_ready) begin
      current_instruction_d = im_rdata;
    end  else begin
      current_instruction_d = current_instruction_q;
    end
  end

  assign current_instruction_valid_d = (dec_en_flag_q && dec_ready)? !dec_flush_pipeline : current_instruction_valid_q;

  //Decoder Enable Reg
  assign dec_en_flag_d = (cfg_dec_en_flag_we)? cfg_dec_en_flag : dec_en_flag_q;

  //PC HW loop
  assign pc_en    = dec_en_flag_q && dec_ready;
  assign pc_we    = cfg_pc_we | dec_pc_we;
  assign pc_wdata = (cfg_pc_we)? cfg_pc_wdata : dec_pc_wdata;

  //HD-Memory
  assign hd_mem_we_o         = hd_mem_we_q;
  assign hd_mem_write_mode_o = hd_mem_write_mode_q;
  assign hd_mem_write_addr_o = hd_mem_write_addr_q;
  assign hd_mem_word_o       = hd_mem_word_wdata_q;

  //Instruction Memory Address Multiplexer
  assign im_addr = (cfg_im_req)? cfg_im_addr : pc_rdata;

  //Int Man Value
  assign enc_int_man_value_o = man_value_reg_q;

  //Host interrupt output
  assign host_intr_o = dec_host_intr;

  //Mutliplex r/w address for hd-memory
  always_comb
    begin
      hd_mem_we_d                   = dec_hd_mem_we;
      hd_mem_write_mode_d           = dec_hd_mem_write_mode;
      if (IS_FOLDED) begin
        hd_mem_read_addr_o.row_addr  = {dec_hd_mem_vector_read_idx, offset_cntr_q};
        hd_mem_write_addr_d.row_addr = {dec_hd_mem_vector_write_idx, offset_cntr_q};
      end else begin
        hd_mem_read_addr_o.row_addr  = dec_hd_mem_vector_read_idx;
        hd_mem_write_addr_d.row_addr = dec_hd_mem_vector_write_idx;
      end
      hd_mem_read_addr_o.word_addr  = 'X;
      hd_mem_write_addr_d.word_addr = 'X;
      if (cfg_hd_mem_req) begin
        if (cfg_hd_mem_we) begin
          hd_mem_we_d         = cfg_hd_mem_we;
          hd_mem_write_mode_d = cfg_hd_mem_write_mode;
          hd_mem_write_addr_d = cfg_hd_mem_addr;
        end else begin
          hd_mem_read_addr_o = cfg_hd_mem_addr;
        end
      end
    end

  //Offset Counter
  if (IS_FOLDED) begin
    always_comb
      begin
        priority if (cfg_offset_cntr_we) begin
          offset_cntr_d = cfg_offset_wdata;
        end else if (dec_offset_cntr_clr) begin
          offset_cntr_d = '0;
        end else if (dec_offset_cntr_en) begin
          if (dec_offset_cntr_dir) begin
            offset_cntr_d = offset_cntr_q + 1;
          end else begin
            offset_cntr_d = offset_cntr_q - 1;
          end
        end else begin
          offset_cntr_d = offset_cntr_q;
        end
      end // always_comb

    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni) begin
        offset_cntr_q <= '0;
      end else begin
        offset_cntr_q <= offset_cntr_d;
      end
    end
  end   else begin
    assign offset_cntr_q = '0;
  end

  //Internal MAN Value
  always_comb
    begin
      priority if (cfg_man_value_reg_we) begin
        man_value_reg_d = cfg_man_value_reg_wdata;
      end else if (dec_man_value_reg_we) begin
        man_value_reg_d = dec_man_value_reg;
      end else begin
        man_value_reg_d = man_value_reg_q;
      end
    end


  //----------------- Submodule Instantiation -----------------

  scm_1rw #(
    .WORD_WIDTH(pkg_ucode_decoder::INSTRUCTION_WIDTH),
    .ROW_CNT(IM_ROW_CNT)
    ) i_instruction_memory(
    .clk_i,
    .rst_ni,
    .we_i(cfg_im_we),
    .addr_i(im_addr),
    .data_i(cfg_im_wdata),
    .data_o(im_rdata)
    );

  pc_hwl_mod i_pc(
    .clk_i,
    .rst_ni,
    .pc_en_i(pc_en),
    .pc_we_i(pc_we),
    .pc_i(pc_wdata),
    .pc_o(pc_rdata),
    .hwl_we_i(dec_pc_hwl_we),
    .hwl_sel_i(dec_pc_hwl_sel),
    .hwl_end_addr_i(dec_pc_hwl_end_addr),
    .hwl_iterations_i(dec_pc_hwl_iterations)
    );



  ucode_decoder i_ucode_decoder(
    .clk_i,
    .rst_ni,
    .en_i(dec_en_flag_q),
    .instruction_i(current_instruction_q),
    .instruction_valid_i(current_instruction_valid_q),
    .flush_pipeline_o(dec_flush_pipeline),
    .hd_mem_am_search_valid_i,
    .hd_mem_am_search_start_o,
    .hd_mem_am_search_stall_o,
    .hd_mem_am_search_is_min_i,
    .hd_mem_am_search_end_idx_o,
    .hd_mem_am_search_result_idx_i,
    .hd_mem_am_search_distance_i,
    .idata_i,
    .idata_valid_i,
    .idata_switch_channel_o,
    .idata_ack_sample_o,
    .host_clr_intr_i(cfg_dec_host_clr_intr),
    .host_intr_o(dec_host_intr),
    .ready_o(dec_ready),
    .pc_we_o(dec_pc_we),
    .pc_wdata_o(dec_pc_wdata),
    .pc_hwl_we_o(dec_pc_hwl_we),
    .pc_hwl_sel_o(dec_pc_hwl_sel),
    .pc_hwl_iterations_o(dec_pc_hwl_iterations),
    .pc_hwl_end_addr_o(dec_pc_hwl_end_addr),
    .hd_mem_we_o(dec_hd_mem_we),
    .hd_mem_write_mode_o(dec_hd_mem_write_mode),
    .hd_mem_vector_read_idx_o(dec_hd_mem_vector_read_idx),
    .hd_mem_vector_write_idx_o(dec_hd_mem_vector_write_idx),
    .enc_mixer_en_o,
    .enc_mixer_perm_sel_o,
    .enc_mixer_inverse_o,
    .enc_input_sel_o,
    .enc_man_en_o,
    .enc_man_value_sel_o,
    .enc_op_sel_o,
    .enc_bundle_cntr_en_o,
    .enc_bundle_cntr_rst_o,
    .enc_bundle_ctx_idx_o,
    .enc_bundle_ctx_we_o,
    .enc_bundle_ctx_add_o,
    .offset_cntr_i(offset_cntr_q),
    .offset_cntr_clr_o(dec_offset_cntr_clr),
    .offset_cntr_en_o(dec_offset_cntr_en),
    .offset_cntr_dir_o(dec_offset_cntr_dir),
    .man_value_reg_we_o(dec_man_value_reg_we),
    .man_value_reg_o(dec_man_value_reg),
    .result_reg_idx_o(dec_cfg_result_reg_idx),
    .result_reg_distance_o(dec_cfg_result_reg_distance)
    );




  config_unit i_config_unit
    (
     .clk_i,
     .rst_ni,
     .cfg_req_i,
     .cfg_gnt_o,
     .cfg_wen_i,
     .cfg_addr_i,
     .cfg_wdata_i,
     .cfg_rdata_o,
     .cfg_rvalid_o,
     .pc_we_o(cfg_pc_we),
     .pc_rdata_i(pc_rdata),
     .pc_wdata_o(cfg_pc_wdata),
     .hd_mem_req_o(cfg_hd_mem_req),
     .hd_mem_we_o(cfg_hd_mem_we),
     .hd_mem_write_mode_o(cfg_hd_mem_write_mode),
     .hd_mem_addr_o(cfg_hd_mem_addr),
     .hd_mem_word_i(hd_mem_word_i),
     .hd_mem_word_o(hd_mem_word_wdata_d),
     .im_req_o(cfg_im_req),
     .im_we_o(cfg_im_we),
     .im_addr_o(cfg_im_addr),
     .im_data_i(im_rdata),
     .im_data_o(cfg_im_wdata),
     .offset_cntr_we_o(cfg_offset_cntr_we),
     .offset_cntr_i(offset_cntr_q),
     .offset_cntr_o(cfg_offset_wdata),
     .man_value_reg_we_o(cfg_man_value_reg_we),
     .man_value_reg_i(man_value_reg_q),
     .man_value_reg_o(cfg_man_value_reg_wdata),
     .dec_en_flag_we_o(cfg_dec_en_flag_we),
     .dec_en_flag_i(dec_en_flag_q),
     .dec_en_flag_o(cfg_dec_en_flag),
     .nxt_instr_reg_we_o(cfg_nxt_instr_we),
     .nxt_instr_reg_i(current_instruction_q),
     .nxt_instr_reg_o(cfg_nxt_instr),
     .result_reg_distance_i(dec_cfg_result_reg_distance),
     .result_reg_idx_i(dec_cfg_result_reg_idx),
     .host_clr_intr_o(cfg_dec_host_clr_intr),
     .host_intr_i(dec_host_intr)
    );


  always_ff @(posedge clk_i, negedge rst_ni)
    begin
      if (!rst_ni) begin
        current_instruction_q       <= '0;
        current_instruction_valid_q <= 1'b0;
        hd_mem_we_q                 <= '0;
        hd_mem_write_addr_q         <= '0;
        hd_mem_write_mode_q         <= pkg_hd_memory::WordMode;
        hd_mem_word_wdata_q         <= '0;
        man_value_reg_q             <= '0;
        dec_en_flag_q               <= '0;
      end else begin
        current_instruction_q       <= current_instruction_d;
        current_instruction_valid_q <= current_instruction_valid_d;
        hd_mem_we_q                 <= hd_mem_we_d;
        hd_mem_write_addr_q         <= hd_mem_write_addr_d;
        hd_mem_write_mode_q         <= hd_mem_write_mode_d;
        hd_mem_word_wdata_q         <= hd_mem_word_wdata_d;
        man_value_reg_q             <= man_value_reg_d;
        dec_en_flag_q               <= dec_en_flag_d;
      end
    end



endmodule : ucode_sequencer

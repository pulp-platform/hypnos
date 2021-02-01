//-----------------------------------------------------------------------------
// Title         : HD Accelerator
//-----------------------------------------------------------------------------
// File          : hd_accelerator.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 02.10.2018
//-----------------------------------------------------------------------------
// Description :
// This is the functional toplevel module of the HD-accelerator
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

module hd_accelerator
  import pkg_common::*;
  (
    input logic                          clk_i,
    input logic                          rst_ni,
    input logic                          dft_test_mode_i, 
    //----------------- Host Interrupt Interface -----------------
    output logic                         host_intr_o,
    //--------------------- Config Interface ---------------------
    input logic                          cfg_req_i,
    output logic                         cfg_gnt_o,
    input logic                          cfg_wen_i,
    input pkg_memory_mapping::cfg_addr_t cfg_addr_i,
    input word_t                         cfg_wdata_i,
    output word_t                        cfg_rdata_o,
    output logic                         cfg_rvalid_o,
    //----------------- Interface to Input Stage -----------------
    output logic                         idata_ack_sample_o,
    output logic                         idata_switch_channel_o,
    input logic                          idata_valid_i,
    input logic [PREPROC_DATA_WIDTH-1:0] idata_i
    );

  //--------------------- Wiring Signals ---------------------
  //HD-Memory
  row_t                               hd_mem_enc_row;
  word_t                              hd_mem_seq_word;
  logic                               hd_mem_seq_valid;
  logic                               hd_mem_seq_am_search_valid;
  logic                               hd_mem_seq_am_search_is_min;
  vector_idx_t                        hd_mem_seq_am_search_result_idx;
  hamming_distance_t                  hd_mem_seq_am_search_distance;


  //uCode Sequencer
  logic                               seq_hd_mem_we;
  pkg_hd_memory::write_mode_t         seq_hd_mem_write_mode;
  addr_t                              seq_hd_mem_raddr;
  addr_t                              seq_hd_mem_waddr;
  word_t                              seq_hd_mem_word;
  logic                               seq_hd_mem_am_search_start;
  logic                               seq_hd_mem_am_search_stall;
  vector_idx_t                        seq_hd_mem_am_search_end_idx;
  man_value_t                         seq_enc_int_man_value;
  logic                               seq_enc_mixer_en;
  logic                               seq_enc_mixer_inverse;
  logic                               seq_enc_mixer_perm_sel;
  pkg_hd_encoder::input_sel_t         seq_enc_input_sel;
  logic                               seq_enc_man_en;
  pkg_hd_encoder::man_value_sel_t     seq_enc_man_value_sel;
  pkg_hd_unit::operand_sel_e          seq_enc_op_sel;
  logic                               seq_enc_bundle_cntr_en;
  logic                               seq_enc_bundle_cntr_rst;
  pkg_hd_unit::bundle_ctx_idx_t       seq_enc_bundle_ctx_idx;
  logic                               seq_enc_bundle_ctx_we;
  logic                               seq_enc_bundle_ctx_add;


  //HD Encoder
  row_t                               enc_hd_mem_row;

  //----------------- Submodule Instantiation -----------------
  hd_memory i_hd_memory(
    .clk_i,
    .rst_ni,
    .test_en_i(dft_test_mode_i),
    .we_i(seq_hd_mem_we),
    .write_mode_i(seq_hd_mem_write_mode),
    .read_addr_i(seq_hd_mem_raddr),
    .write_addr_i(seq_hd_mem_waddr),
    .row_i(enc_hd_mem_row),
    .row_o(hd_mem_enc_row),
    .word_i(seq_hd_mem_word),
    .word_o(hd_mem_seq_word),
    .valid_o(),
    .am_search_start_i(seq_hd_mem_am_search_start),
    .am_search_stall_i(seq_hd_mem_am_search_stall),
    .am_search_end_idx_i(seq_hd_mem_am_search_end_idx),
    .am_search_valid_o(hd_mem_seq_am_search_valid),
    .am_search_is_min_o(hd_mem_seq_am_search_is_min),
    .am_search_result_idx_o(hd_mem_seq_am_search_result_idx),
    .am_search_distance_o(hd_mem_seq_am_search_distance));


  hd_encoder i_hd_encoder(.clk_i,
    .rst_ni,
    .ext_man_value_i(idata_i[MAN_VALUE_WIDTH-1:0]),
    .int_man_value_i(seq_enc_int_man_value),
    .vector_i(hd_mem_enc_row),
    .vector_o(enc_hd_mem_row),
    .mixer_en_i(seq_enc_mixer_en),
    .mixer_inverse_i(seq_enc_mixer_inverse),
    .mixer_perm_sel_i(seq_enc_mixer_perm_sel),
    .man_en_i(seq_enc_man_en),
    .man_input_sel_i(seq_enc_input_sel),
    .man_value_sel_i(seq_enc_man_value_sel),
    .hd_op_sel_i(seq_enc_op_sel),
    .en_bundle_cntr_i(seq_enc_bundle_cntr_en),
    .rst_bundle_cntr_i(seq_enc_bundle_cntr_rst),
    .bundle_ctx_idx_i(seq_enc_bundle_ctx_idx),
    .bundle_ctx_we_i(seq_enc_bundle_ctx_we),
    .bundle_ctx_add_i(seq_enc_bundle_ctx_add)
    );


  ucode_sequencer i_ucode_sequencer(
    .clk_i,
    .rst_ni,
    .hd_mem_we_o(seq_hd_mem_we),
    .hd_mem_write_mode_o(seq_hd_mem_write_mode),
    .hd_mem_read_addr_o(seq_hd_mem_raddr),
    .hd_mem_write_addr_o(seq_hd_mem_waddr),
    .hd_mem_word_i(hd_mem_seq_word),
    .hd_mem_word_o(seq_hd_mem_word),
    .hd_mem_am_search_start_o(seq_hd_mem_am_search_start),
    .hd_mem_am_search_stall_o(seq_hd_mem_am_search_stall),
    .hd_mem_am_search_is_min_i(hd_mem_seq_am_search_is_min),
    .hd_mem_am_search_end_idx_o(seq_hd_mem_am_search_end_idx),
    .hd_mem_am_search_valid_i(hd_mem_seq_am_search_valid),
    .hd_mem_am_search_result_idx_i(hd_mem_seq_am_search_result_idx),
    .hd_mem_am_search_distance_i(hd_mem_seq_am_search_distance),
    .enc_input_sel_o(seq_enc_input_sel),
    .enc_man_en_o(seq_enc_man_en),
    .enc_man_value_sel_o(seq_enc_man_value_sel),
    .enc_int_man_value_o(seq_enc_int_man_value),
    .enc_mixer_en_o(seq_enc_mixer_en),
    .enc_mixer_inverse_o(seq_enc_mixer_inverse),
    .enc_mixer_perm_sel_o(seq_enc_mixer_perm_sel),
    .enc_op_sel_o(seq_enc_op_sel),
    .enc_bundle_cntr_en_o(seq_enc_bundle_cntr_en),
    .enc_bundle_cntr_rst_o(seq_enc_bundle_cntr_rst),
    .enc_bundle_ctx_idx_o(seq_enc_bundle_ctx_idx),
    .enc_bundle_ctx_we_o(seq_enc_bundle_ctx_we),
    .enc_bundle_ctx_add_o(seq_enc_bundle_ctx_add),
    .idata_i,
    .idata_valid_i,
    .idata_ack_sample_o,
    .idata_switch_channel_o,
    .host_intr_o,
    .cfg_req_i,
    .cfg_gnt_o,
    .cfg_wen_i,
    .cfg_addr_i,
    .cfg_wdata_i,
    .cfg_rdata_o,
    .cfg_rvalid_o
    );
endmodule : hd_accelerator

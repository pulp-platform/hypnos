//-----------------------------------------------------------------------------
// Title         : hd_encoder
//-----------------------------------------------------------------------------
// File          : hd_encoder.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 28.09.2018
//-----------------------------------------------------------------------------
// Description :
// This module contains the whole HD-encoder that performs all the HD-operations
// except for associative search.
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

module hd_encoder
  import pkg_common::*;
  import pkg_hd_encoder::*;
  (
    input logic                         clk_i,
    input logic                         rst_ni,
    //---------------------- Datapath Input ----------------------
    input man_value_t                   ext_man_value_i,
    input man_value_t                   int_man_value_i,
    input row_t                         vector_i,
    output row_t                        vector_o,
    //------------------ Mixer Control Signals ------------------
    input logic                         mixer_en_i,
    input logic                         mixer_inverse_i,
    input logic                         mixer_perm_sel_i,
    //------------------- MAN Control Signals -------------------
    input logic                         man_en_i,
    input input_sel_t                   man_input_sel_i,
    input man_value_sel_t               man_value_sel_i,
    //----------------- HD-unit Control Signals -----------------
    input pkg_hd_unit::operand_sel_e    hd_op_sel_i,
    input logic                         en_bundle_cntr_i,
    input logic                         rst_bundle_cntr_i,
    input pkg_hd_unit::bundle_ctx_idx_t bundle_ctx_idx_i,
    input logic                         bundle_ctx_we_i,
    input logic                         bundle_ctx_add_i
  );


  //--------------------- Datapath Signals ---------------------
  row_t                              man_input;
  row_t                              man_to_mixer;
  row_t                              mixer_to_hd_units;
  man_value_t                        man_value_input;
  logic [MEM_ROW_WIDTH+1:0]          appended_carry_helper;

  //------------------ Module Instantiations ------------------
  man_module #(.VALUE_WIDTH(MAN_VALUE_WIDTH),
    .VEC_WIDTH(MEM_ROW_WIDTH))
  i_man_module(
    .en_i(man_en_i),
    .value_i(man_value_input),
    .vector_i(man_input.row),
    .vector_o(man_to_mixer.row));

  mixer i_mixer(.en_i(mixer_en_i),
    .inverse_i(mixer_inverse_i),
    .perm_sel_i(mixer_perm_sel_i),
    .row_i(man_to_mixer),
    .row_o(mixer_to_hd_units));

  for (genvar k=0; k<MEM_ROW_WIDTH; k++) begin : gen_hd_units
    hd_unit i_hd_unit (
                       .clk_i,
                       .rst_ni,
                       .bit_i(appended_carry_helper[k+1]),
                       .sel_op_i(hd_op_sel_i),
                       .en_bundle_cntr_i(en_bundle_cntr_i),
                       .rst_bundle_cntr_i(rst_bundle_cntr_i),
                       .bit_left_i(appended_carry_helper[k+2]),
                       .bit_right_i(appended_carry_helper[k]),
                       .result_bit_o(vector_o[k]),
                       .bundle_ctx_we_i,
                       .bundle_ctx_idx_i,
                       .bundle_ctx_add_i
                       );
  end

  assign appended_carry_helper[MEM_ROW_WIDTH:1] = mixer_to_hd_units.row;
  assign appended_carry_helper[0] = mixer_to_hd_units.row[MEM_ROW_WIDTH-1];
  assign appended_carry_helper[MEM_ROW_WIDTH+1] = mixer_to_hd_units.row[0];

  //----------------------- Multiplexer -----------------------
  always_comb
    begin
      unique case(man_input_sel_i)
        OUTPUT_REG:
          man_input = vector_o;
        MEMORY:
          man_input = vector_i;
        ZERO:
          man_input = '0;
        default:
          man_input = vector_i;
      endcase
    end

  always_comb
    begin
      unique case(man_value_sel_i)
        EXTERNAL:
          man_value_input = ext_man_value_i;
        INTERNAL:
          man_value_input = int_man_value_i;
        default:
          man_value_input = int_man_value_i;
      endcase
    end

endmodule : hd_encoder

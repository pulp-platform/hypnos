//-----------------------------------------------------------------------------
// Title         : Manipulator module 
//-----------------------------------------------------------------------------
// File          : man_module.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 24.09.2018
//-----------------------------------------------------------------------------
// Description :
// This flips a configurable number of bits of an input HD-vector. The module is used
// for CIM binarized b2b bundling and other operations in the HD-encoder
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

module man_module
  import pkg_common::*;
  import pkg_perm_final::*;
  #(parameter VALUE_WIDTH=7,
    parameter VEC_WIDTH=MEM_ROW_WIDTH)
   (
    input logic en_i,
    input logic [VALUE_WIDTH-1:0] value_i,
    input logic [VEC_WIDTH-1:0]   vector_i,
    output logic [VEC_WIDTH-1:0]  vector_o
    );
   localparam UNARY_CODE_WIDTH = 2**VALUE_WIDTH;
   localparam REP_CODER_SPREAD = VEC_WIDTH/(2*UNARY_CODE_WIDTH);

   logic [UNARY_CODE_WIDTH-1:0]   unary_coder_output;
   logic [2*UNARY_CODE_WIDTH-1:0] rep_coder_input;
   logic [VEC_WIDTH-1:0]          rep_coder_output;
   logic [VEC_WIDTH-1:0]          final_permutator_output;

  unary_encoder #(.INPUT_WIDTH(VALUE_WIDTH)) i_unary_enc (.value_i,.unary_o(unary_coder_output));

  //Append UNARY_CODE_WIDTH zeros to the unary_code since an input value of all
  //ones (max value) should eventually toggle not all but half of the input
  //vector bits.
  assign rep_coder_input = {unary_coder_output, {UNARY_CODE_WIDTH{1'b0}}};


  //Repetition encoder
  always_comb
    begin
      foreach(rep_coder_input[i]) begin
        for (int j = 0; j<REP_CODER_SPREAD; j++) begin
          rep_coder_output[i*REP_CODER_SPREAD+j] = rep_coder_input[i];
        end
      end
    end

  //Final permutator that generate signal to xor with input vector_o
  assign final_permutator_output = perm_final(rep_coder_output,0);

  //Output assignment
  assign vector_o = (en_i) ? final_permutator_output ^ vector_i : vector_i;
endmodule : man_module

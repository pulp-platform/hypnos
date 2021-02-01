//-----------------------------------------------------------------------------
// Title         : Mixer
//-----------------------------------------------------------------------------
// File          : mixer.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 28.09.2018
//-----------------------------------------------------------------------------
// Description :
// If enabled this module permuates the input vector with one of two permutation
// matrices depending on the perm_sel_i signal.
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

module mixer
  import pkg_common::*;
   import pkg_mixer_permutate::*;
   (
    input logic                      en_i,
    input logic                      inverse_i,
    input logic                      perm_sel_i,
    input logic [MEM_ROW_WIDTH-1:0]  row_i,
    output logic [MEM_ROW_WIDTH-1:0] row_o
    );

   logic [MEM_ROW_WIDTH-1:0]            mixed_a;
   logic [MEM_ROW_WIDTH-1:0]            mixed_b;
   logic [MEM_ROW_WIDTH-1:0]            inverse_mixed_a;
   logic [MEM_ROW_WIDTH-1:0]            inverse_mixed_b;

   assign mixed_a = mixer_permutate(row_i,0);
   assign mixed_b = mixer_permutate(row_i,1);
   assign inverse_mixed_a = mixer_permutate_inverse(row_i, 0);
   assign inverse_mixed_b = mixer_permutate_inverse(row_i, 1);

   //Output MUX
   always_comb
     begin
       if (en_i == 1'b1)
         begin
           if (inverse_i == 1'b0) begin
             row_o = (perm_sel_i == 1'b0)? mixed_a : mixed_b;
           end else begin
             row_o = (perm_sel_i == 1'b0)? inverse_mixed_a : inverse_mixed_b;
           end
         end else begin
           row_o = row_i;
         end
     end
endmodule : mixer

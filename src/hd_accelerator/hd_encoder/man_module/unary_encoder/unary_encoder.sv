//-----------------------------------------------------------------------------
// Title         : Unary Encoder
//-----------------------------------------------------------------------------
// File          : unary_encoder.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 24.09.2018
//-----------------------------------------------------------------------------
// Description :
// Encodes the input value in unary code (aka thermometer code).
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
module unary_encoder
  #(
    parameter INPUT_WIDTH=7,
    localparam OUTPUT_WIDTH=2**INPUT_WIDTH
    )
   (input logic[INPUT_WIDTH-1:0] value_i,
    output logic[OUTPUT_WIDTH-1:0] unary_o);

   always_comb
     begin
       for (int unsigned i = 0; i < OUTPUT_WIDTH; i++) begin
         if (i < value_i+1) begin
           unary_o[i] = 1'b1;
         end else begin
           unary_o[i] = 1'b0;
         end
       end
     end

endmodule : unary_encoder

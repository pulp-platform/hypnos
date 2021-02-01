//-----------------------------------------------------------------------------
// Title : Local Binary Pattern Generator
// -----------------------------------------------------------------------------
// File : lbp.sv Author : Manuel Eggimann <meggimann@iis.ee.ethz.ch> Created :
// 18.03.2019
// -----------------------------------------------------------------------------
// Description : Generates local binary patterns LBP for the given input data
// with parametric code size. For every CODESIZE input value there will be a
// single valid output word.
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

module lbp
  #(
    parameter CODEZIZE = 6,
    parameter DATA_WIDTH = 32
    )
  (
   input logic                  clk_i,
   input logic                  rst_ni,
   input logic                  clear_i,
   input logic                  en_i,
   input logic [DATA_WIDTH-1:0] data_i,
   output logic [CODEZIZE-1:0]  lbp_o,
   output logic                 lbp_valid_o);

  logic [DATA_WIDTH-1:0]        prev_data_d, prev_data_q;
  logic [CODEZIZE-1:0]          lbp_d, lbp_q;
  logic [$clog2(CODEZIZE)-1:0]  bit_cntr_d, bit_cntr_q;

  assign lbp_o = lbp_q;

  always_comb begin
    lbp_d       = lbp_q;
    prev_data_d = prev_data_q;
    bit_cntr_d  = bit_cntr_q;
    lbp_valid_o = 1'b0;
    if (clear_i) begin
      lbp_d       = '0;
      prev_data_d = '0;
      bit_cntr_d  = '0;
    end else if (en_i) begin
      lbp_d = {lbp_q[CODEZIZE-2:0], (data_i>prev_data_q)};
      prev_data_d = data_i;
      if (bit_cntr_q != CODEZIZE-1) begin
        bit_cntr_d  = bit_cntr_q+1;
      end else begin
        lbp_valid_o = 1'b1;
        bit_cntr_d  = '0;
      end
    end
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      prev_data_q <= '0;
      lbp_q       <= '0;
      bit_cntr_q  <= '0;
    end else begin
      prev_data_q <= prev_data_d;
      lbp_q       <= lbp_d;
      bit_cntr_q  <= bit_cntr_d;
    end
  end
endmodule : lbp

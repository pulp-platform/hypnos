//-----------------------------------------------------------------------------
// Title         : SCM 1R1W without read buffer
//-----------------------------------------------------------------------------
// File          : scm_1r_1w.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 25.10.2018
//-----------------------------------------------------------------------------
// Description :
// A latch based standard cell memory without the read buffer register.
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

module scm_1r1w
  #(parameter WORD_WIDTH = 25,
    parameter ROW_CNT = 64,
    localparam ADDR_WIDTH = $clog2(ROW_CNT))
   (
    input logic                   clk_i,
    input logic                   rst_ni,
    input logic                   we_i,
    input logic [ADDR_WIDTH-1:0]  raddr_i,
    output logic [WORD_WIDTH-1:0] data_o,
    input logic [ADDR_WIDTH-1:0]  waddr_i,
    input logic [WORD_WIDTH-1:0]  data_i);

   //----------------------- Internal signals -----------------------
   logic [WORD_WIDTH-1:0] wdata_d, wdata_q;
   logic                  we_clk;
   logic                  word_clk [ROW_CNT];
   logic                  word_we [ROW_CNT];
   logic [WORD_WIDTH-1:0] memory_q [ROW_CNT];

   assign data_o = memory_q[raddr_i];

   //----------------------- Clock gating -----------------------

   cluster_clock_gating we_gate_global
     (
      .clk_i,
      .en_i(we_i),
      .test_en_i(1'b0),
      .clk_o(we_clk)
      );

   //One-hot decoding for enable signal of the word clock gates
   always_comb
     begin
       word_we = '{default:'0};
       word_we[waddr_i] = 1'b1;
     end

   for(genvar i=0; i<ROW_CNT; i++)
     begin
       cluster_clock_gating word_clk_gate
                (
                 .clk_i(we_clk),
                 .en_i(word_we[i]),
                 .test_en_i(1'b0),
                 .clk_o(word_clk[i])
                 );
     end

   //----------------------- Write buffer -----------------------
   assign wdata_d = data_i;

   always_ff @(posedge clk_i, negedge rst_ni)
     begin
       if (!rst_ni) begin
         wdata_q <= '0;
       end else begin
         if (we_i) begin
           wdata_q <= wdata_d;
         end
       end
     end // always_ff @ (posedge clk_i, negedge rst_ni)

   //----------------------- Latch Memory -----------------------
   always_latch
     begin
       foreach( memory_q[i]) begin
         if (word_clk[i]) begin
           memory_q[i] <= wdata_q;
         end
       end
     end

endmodule : scm_1r1w

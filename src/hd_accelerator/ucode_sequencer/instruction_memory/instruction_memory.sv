//-----------------------------------------------------------------------------
// Title         : Instruction Memory
//-----------------------------------------------------------------------------
// File          : instruction_memory.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 08.10.2018
//-----------------------------------------------------------------------------
// Description :
// The instruction memory stores the ucode to execute for the hd-computing algorithm
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

module instruction_memory
  import pkg_common::*;
   import pkg_ucode_decoder::instruction_t;
  #(parameter IM_ADDR_WIDTH=4)
   (
    input logic          clk_i,
    input logic          rst_ni,
    input logic          we_i,
    input im_addr_t      addr_i,
    input instruction_t  data_i,
    output instruction_t data_o
    );

   localparam IM_ROW_CNT = 2**IM_ADDR_WIDTH;

   instruction_t             memory_d[IM_ROW_CNT];
   instruction_t             memory_q[IM_ROW_CNT];

   assign data_o = memory_q[addr_i];

   always_comb
     begin
       memory_d = memory_q;
       if (we_i) begin
         memory_d[addr_i] = data_i;
       end
     end

   always_ff @(posedge clk_i, negedge rst_ni)
     begin
       if (!rst_ni) begin
         memory_q <= '{default:0};
       end else begin
         memory_q <= memory_d;
       end
     end
endmodule : instruction_memory

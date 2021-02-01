//-----------------------------------------------------------------------------
// Title         : Program Counter + HW loop engine
//-----------------------------------------------------------------------------
// File          : pc_hwl_mod.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 09.10.2018
//-----------------------------------------------------------------------------
// Description :
// This Module combines the program counter and the hardware loop engine used in
// the uCode sequencer.
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

module pc_hwl_mod
  import pkg_common::*;
   (input logic clk_i,
    input logic                     rst_ni,
    input logic                     pc_en_i, //Enable signal for the program counter
    input logic                     pc_we_i, //Write enable for the program counter
    input im_addr_t                 pc_i, //input to override pc externally
    output im_addr_t                pc_o, //current value of pc
    input logic                     hwl_we_i, // enables writing to the config registers of the selected hw-loop
    input logic [HWL_SEL_WIDTH-1:0] hwl_sel_i, //selects the hwl to configure
    input im_addr_t                 hwl_end_addr_i,
    input hwl_iterations_t          hwl_iterations_i
    );

   //--------------------- Internal Signals ---------------------
   im_addr_t                        pc_d, pc_q;
   //hw-loop counters
   logic [HWL_CNTR_WITH-1:0]        hwl_cntrs_d[HWL_REGS_CNT];
   logic [HWL_CNTR_WITH-1:0]        hwl_cntrs_q[HWL_REGS_CNT];
   logic                            hwl_cntrs_dec[HWL_REGS_CNT];

   //hw-loop address regs
   im_addr_t                        hwl_start_addr_d[HWL_REGS_CNT];
   im_addr_t                        hwl_start_addr_q[HWL_REGS_CNT];
   im_addr_t                        hwl_end_addr_d[HWL_REGS_CNT];
   im_addr_t                        hwl_end_addr_q[HWL_REGS_CNT];
   logic [0:HWL_REGS_CNT-1]         hwl_end_addr_match;

   logic [0:HWL_REGS_CNT-1]         hwl_is_one; //helper signal that is high if the corresponding hwl counter equals 1.
   logic [0:HWL_REGS_CNT-1]         hwl_is_zero;//helper signal that is high if the corresponding hwl counter equals 0.


   assign pc_o = pc_q;

   //------------------- Comabinational logic -------------------
   //comparators
   generate
     for (genvar i=0; i<HWL_REGS_CNT; i++) begin
       assign hwl_end_addr_match[i] = (pc_q == hwl_end_addr_q[i]);
     end
   endgenerate

   //helper signal
   generate
     for (genvar i=0; i<HWL_REGS_CNT; i++) begin
       assign hwl_is_one[i] = (hwl_cntrs_q[i] == 1);
     end
   endgenerate

   //helper signal
   generate
     for (genvar i=0; i<HWL_REGS_CNT; i++) begin
       assign hwl_is_zero[i] = (hwl_cntrs_q[i] == '0);
     end
   endgenerate

   //Determine which loops to decrement
   assign hwl_cntrs_dec[0] = (hwl_end_addr_match[0] & !hwl_is_zero[0]);
   generate
     for (genvar i=1; i<HWL_REGS_CNT; i++) begin
       always_comb
         begin
           if (hwl_end_addr_match[i] && !hwl_is_zero[i] && ((hwl_end_addr_match[0:i-1] & ~hwl_is_zero[0:i-1] & ~hwl_is_one[0:i-1]) == '0)) begin
             hwl_cntrs_dec[i] = 1'b1;
           end else begin
             hwl_cntrs_dec[i] = 1'b0;
           end
         end
     end
   endgenerate

   //Loop counters + address registers
   generate
     for (genvar i=0; i<HWL_REGS_CNT; i++) begin
       always_comb
         begin
           priority if ((hwl_sel_i == i) && hwl_we_i) begin
             hwl_cntrs_d[i]        = hwl_iterations_i;
             hwl_start_addr_d[i]   = pc_q;
             hwl_end_addr_d[i]     = hwl_end_addr_i;
           end else if (pc_en_i) begin
             hwl_start_addr_d[i] = hwl_start_addr_q[i];
             hwl_end_addr_d[i]   = hwl_end_addr_q[i];
             if (hwl_cntrs_dec[i] == 1'b1) begin
               hwl_cntrs_d[i] = hwl_cntrs_q[i]-1;
             end else begin
               hwl_cntrs_d[i] = hwl_cntrs_q[i];
             end
           end else begin
             hwl_cntrs_d[i]     = hwl_cntrs_q[i];
             hwl_start_addr_d[i] = hwl_start_addr_q[i];
             hwl_end_addr_d[i] = hwl_end_addr_q[i];
           end
         end
     end
   endgenerate

   //Program counter
   always_comb
     begin
       priority if (pc_we_i) begin
         pc_d = pc_i;
       end else if (pc_en_i) begin
         pc_d = pc_q+1;
         for (int i = 0; i<HWL_REGS_CNT; i++) begin
           if (hwl_cntrs_dec[i] & !hwl_is_one[i]) begin
             pc_d = hwl_start_addr_q[i]; //Jump to start address of active hwl with least priority.
           end
         end
       end else begin
         pc_d = pc_q;
       end
     end

   //Sequential cells
   always_ff @(posedge clk_i, negedge rst_ni)
     begin
       if (!rst_ni) begin
         pc_q             <= '0;
         hwl_cntrs_q      <= '{default:'0};
         hwl_start_addr_q <= '{default:'0};
         hwl_end_addr_q   <= '{default:'0};
       end else begin
         pc_q             <= pc_d;
         hwl_cntrs_q      <= hwl_cntrs_d;
         hwl_start_addr_q <= hwl_start_addr_d;
         hwl_end_addr_q   <= hwl_end_addr_d;
       end
     end
endmodule : pc_hwl_mod

//-----------------------------------------------------------------------------
// Title         : HD Memory
//-----------------------------------------------------------------------------
// File          : hd_memory.sv
// Author        : Manuel Eggimann   <meggimann@iis.ee.ethz.ch>
// Created       : 17.09.2018
//-----------------------------------------------------------------------------
// Description :
// Latch based RAM for storing Hypervectors. Entire rows or single words (several of
// which makeup a row can be written depending on the mode signal.)
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

module hd_memory
  import pkg_common::*;
   import pkg_hd_memory::*;
   (
    input logic               clk_i,
    input logic               rst_ni,
    input logic               test_en_i,
    input logic               we_i,
    input write_mode_t        write_mode_i,
    input addr_t              read_addr_i,
    input addr_t              write_addr_i,
    input row_t               row_i,
    output row_t              row_o,
    input word_t              word_i,
    output word_t             word_o,
    output logic              valid_o,
    input logic               am_search_start_i,
    input logic               am_search_stall_i,
    input vector_idx_t        am_search_end_idx_i,
    output logic              am_search_is_min_o,
    output logic              am_search_valid_o,
    output vector_idx_t       am_search_result_idx_o,
    output hamming_distance_t am_search_distance_o
    );
   localparam bit             IS_FOLDED = ROWS_PER_HDVECT>1;


   row_t                      memory_q[ROW_CNT];
`ifdef FPGA_EMUL
   row_t                      memory_d[ROW_CNT];
`else
   row_t                      write_row;
   logic                      clk_internal;
   logic [0:WORDS_PER_ROW-1]  word_write_en[ROW_CNT];
   logic                      inverted_clk;
   logic [0:WORDS_PER_ROW-1]  clk_gated_en[ROW_CNT];
`endif


   //------------------ Signals for AM-search ------------------
   typedef enum               logic[1:0] {Idle, AMSearch, Done} state_e;
   typedef enum                        logic[0:0] {IntAddr, ExtAddr} addr_sel_e;

   //Registers
   state_e                             state_d, state_q;
   logic                               offset_cntr_en, offset_cntr_clr;
   logic [$clog2(ROWS_PER_HDVECT)-1:0] offset_cntr_d, offset_cntr_q;
   logic                               vector_cntr_en, vector_cntr_clr;
   vector_idx_t                        vector_cntr_d, vector_cntr_q;
   logic                               weight_accumulator_en;
   logic                               weight_accumulator_clr;
   hamming_distance_t                  weight_accumulator_d, weight_accumulator_q;
   hamming_distance_t                  current_weight;
   logic                               min_distance_we;
   logic                               min_distance_clr;
   hamming_distance_t                  min_distance_d, min_distance_q;
   logic                               result_idx_we;
   logic                               result_idx_clr;
   vector_idx_t                        result_idx_d, result_idx_q;

   //Internal signals
   addr_sel_e                          raddr_sel;
   addr_t                              raddr;
   row_t                               read_row;
   row_t                               reference_row;
   row_t                               difference_signal; //xor between current row and search vector (last vector in memory)
   logic [$clog2(MEM_ROW_WIDTH):0]     row_weight;
   logic                               weight_compare;


   //--------------------- Popcount Module ---------------------
   popcount #(.INPUT_WIDTH(MEM_ROW_WIDTH))
   i_popcount(.data_i(difference_signal), .popcount_o(row_weight));


   //------------------ Continuous Assignments ------------------
   assign reference_row     = memory_q[ROW_CNT-ROWS_PER_HDVECT+offset_cntr_q];
   assign difference_signal = reference_row ^ read_row;
   assign current_weight = weight_accumulator_q + row_weight;

   assign weight_compare = ((current_weight) < min_distance_q);

   //Read addr mux
   always_comb begin
     raddr         = 'x;
     if (raddr_sel == IntAddr) begin
       if (IS_FOLDED) begin
         raddr.row_addr = {vector_cntr_q, offset_cntr_q};
       end   else begin
         raddr.row_addr = vector_cntr_q;
       end
     end else begin
       raddr = read_addr_i;
     end
   end

   assign read_row = memory_q[raddr.row_addr];


   //------------------------ Output Port Assignments ------------------------
   assign row_o                    = read_row;
   assign valid_o                  = (raddr_sel == ExtAddr);
   assign word_o                   = read_row.words[read_addr_i.word_addr];
   assign am_search_distance_o     = am_search_is_min_o? min_distance_q : current_weight;
   assign am_search_result_idx_o   = am_search_is_min_o? result_idx_q : vector_cntr_q;

   //------------- AM Search Counters & Comparator -------------
   if (IS_FOLDED) begin
     //Offset Counter
     always_comb begin
       if (offset_cntr_clr) offset_cntr_d = '0;
       else if (offset_cntr_en) offset_cntr_d = offset_cntr_q + 1;
       else offset_cntr_d = offset_cntr_q;
     end

   always_ff @(posedge clk_i, negedge rst_ni) begin
     if (!rst_ni) begin
       offset_cntr_q <= '0;
     end else begin
       if (!am_search_stall_i) begin
         offset_cntr_q <= offset_cntr_d;
       end
     end
   end

end else begin
  assign offset_cntr_q = '0;
end

   //Vector Counter
   always_comb begin
     if (vector_cntr_clr) vector_cntr_d = '0;
     else if (vector_cntr_en) vector_cntr_d = vector_cntr_q + 1;
     else vector_cntr_d = vector_cntr_q;
   end

   //Weight Accumulator
   always_comb begin
     if (weight_accumulator_clr) weight_accumulator_d = '0;
     else if (weight_accumulator_en) weight_accumulator_d = current_weight;
     else weight_accumulator_d = weight_accumulator_q;
   end

   //Min Distance register
   always_comb begin
     if (min_distance_clr) min_distance_d = '1; //Initialize with largest possible value
     else if (min_distance_we & weight_compare) min_distance_d = current_weight;
     else min_distance_d = min_distance_q;
   end

   //Result HD-Vector index register
   always_comb begin
     if (result_idx_clr) result_idx_d = '0;
     else if (result_idx_we & weight_compare) result_idx_d = vector_cntr_q;
     else result_idx_d = result_idx_q;
   end

   //---------------------- AM Search FSM ----------------------
   always_comb begin
     state_d                = state_q;
     offset_cntr_en         = 1'b0;
     offset_cntr_clr        = 1'b0;
     vector_cntr_en         = 1'b0;
     vector_cntr_clr        = 1'b0;
     weight_accumulator_en  = 1'b0;
     weight_accumulator_clr = 1'b0;
     min_distance_we        = 1'b0;
     min_distance_clr       = 1'b0;
     result_idx_we          = 1'b0;
     result_idx_clr         = 1'b0;
     am_search_is_min_o     = 1'b0;
     am_search_valid_o      = 1'b0;
     raddr_sel              = IntAddr;

     unique case(state_q)
       Idle: begin
         if (am_search_start_i) begin
           state_d               = AMSearch;
         end else begin
           raddr_sel = ExtAddr;
         end
       end

       AMSearch: begin
         if (offset_cntr_q == unsigned'(ROWS_PER_HDVECT - 1)) begin
           offset_cntr_clr        = 1'b1;
           weight_accumulator_clr = 1'b1;
           min_distance_we        = 1'b1;
           result_idx_we          = 1'b1;
           am_search_valid_o      = 1'b1;
           if (vector_cntr_q == am_search_end_idx_i) begin
             state_d                = Done;
             vector_cntr_clr        = 1'b0;
           end else begin
             vector_cntr_en         = 1'b1;
           end
         end else begin
           offset_cntr_en        = 1'b1;
           weight_accumulator_en = 1'b1;
         end
       end

       Done: begin
         am_search_is_min_o = 1'b1;
         am_search_valid_o  = 1'b1;
         //Stay in Done state until start is deasserted
         if (!am_search_start_i) begin
           state_d          = Idle;
           offset_cntr_clr  = 1'b1;
           vector_cntr_clr  = 1'b1;
           min_distance_clr = 1'b1;
           result_idx_clr   = 1'b1;
         end
       end

       default: begin
         state_d = Idle;
       end
     endcase
   end // always_comb

   always_ff @(posedge clk_i , negedge rst_ni) begin
     if (!rst_ni) begin
       state_q              <= Idle;
       vector_cntr_q        <= '0;
       weight_accumulator_q <= '0;
       min_distance_q       <= '1; //Initialize with largest possible distance
       result_idx_q         <= '0;
     end else begin
       if (!am_search_stall_i) begin
         state_q              <= state_d;
         vector_cntr_q        <= vector_cntr_d;
         weight_accumulator_q <= weight_accumulator_d;
         min_distance_q       <= min_distance_d;
         result_idx_q         <= result_idx_d;
       end
     end
   end

`ifdef FPGA_EMUL
   always_comb begin
     memory_d = memory_q;
     if (we_i) begin
       if (write_mode_i == WordMode) begin
         memory_d[write_addr_i.row_addr][write_addr_i.word_addr] = word_i;
       end   else begin
         memory_d[write_addr_i.row_addr] = row_i;
       end
     end
   end

   always_ff @(posedge clk_i, negedge rst_ni) begin
     if (!rst_ni) begin
       foreach(memory_q[i]) begin
         memory_q[i].row <= '0;
       end
     end else begin
       foreach(memory_q[i]) begin
         memory_q[i].row <= memory_d[i].row;
       end
     end
   end
`else

   //------------------- Clock inverter gate -------------------
   cluster_clock_inverter i_clk_inv
     (
      .clk_i(clk_i),
      .clk_o(inverted_clk)
      );

   //---------------- Global Write EN Clock Gate ----------------
   cluster_clock_gating i_we_cg_global
     (
      .clk_i(inverted_clk),
      .en_i(we_i),
      .test_en_i(test_en_i),
      .clk_o(clk_internal)
      );

   //Assign input data and enable signals for the currently selected words depending on the write mode (row or word)
   always_comb begin
     word_write_en = '{default:0};
     write_row = row_i;
     if (write_mode_i == WordMode) begin
       word_write_en[write_addr_i.row_addr][write_addr_i.word_addr] = '1;
       write_row.words[write_addr_i.word_addr] = word_i;
     end else begin
       word_write_en[write_addr_i.row_addr] = '1;
     end
   end

   //Clock gate write enable signals to generate clock for the latches
   for (genvar row_idx = 0; row_idx<ROW_CNT;row_idx++) begin : clk_gated_we
     for (genvar word_idx = 0; word_idx<WORDS_PER_ROW; word_idx++) begin
       cluster_clock_gating i_we_gating
                            (.clk_i(clk_internal),
                             .en_i(word_write_en[row_idx][word_idx]),
                             .test_en_i(test_en_i),
                             .clk_o(clk_gated_en[row_idx][word_idx]));
     end
   end

   always_latch begin
     for (int unsigned row_idx = 0; row_idx<ROW_CNT; row_idx++) begin
       for (int unsigned word_idx = 0; word_idx<WORDS_PER_ROW; word_idx++) begin
         if (clk_gated_en[row_idx][word_idx] == 1'b1) begin
           memory_q[row_idx].words[word_idx] <= write_row.words[word_idx];
         end
       end
     end
   end

`endif
endmodule : hd_memory

//-----------------------------------------------------------------------------
// Title         : AM Search Unit
//-----------------------------------------------------------------------------
// File          : am_search_unit.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 18.09.2018
//-----------------------------------------------------------------------------
// Description :
// Determines the hd-vector with the lowest hamming distance from the vector at
// the highest index (VECTOR_CNT-1). This implementation calculates the exact
// Hamming distance.
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

module am_search_unit
  import pkg_common::*;
   import pkg_am_search_unit::*;
   ( 
    input logic               clk_i,
    input logic               rst_ni,
    input logic               start_i,
    output logic              ready_o,
    output logic              valid_o,
    input column_t            column_i,
    output column_addr_t      column_addr_o,
    output vector_idx_t       result_idx_o,
    output hamming_distance_t min_distance_o);

   typedef enum                               logic[1:0] {Idle, Busy, Done} state_t;

   state_t                                    state_d, state_q;

   column_addr_t                              column_addr_cntr_d,column_addr_cntr_q;

   logic [COUNTER_WIDTH-1:0]                  hamming_cntrs_d[ROW_CNT-ROWS_PER_HDVECT]; //We don't need a counter for the last vector since this is the vector used to compare against all the others. 
   logic [COUNTER_WIDTH-1:0]                  hamming_cntrs_q[ROW_CNT-ROWS_PER_HDVECT];
   logic                                      en_hamming_cntrs;
   logic                                      clr_hamming_cntrs;

   hamming_distance_t                         hamming_distances[VECTOR_CNT-1]; //The sum <ROWS_PER_HDVECT> row counters is the hamming distance of the whole hypervector
   logic [0:ROWS_PER_HDVECT-1]                search_vector;


   //----------------------- Assignments -----------------------
   assign search_vector = column_i[ROW_CNT-ROWS_PER_HDVECT+:ROWS_PER_HDVECT];
   assign column_addr_o = column_addr_cntr_q;

   //--------------------------- FSM ---------------------------
   always_comb
     begin
       state_d = state_q;
       column_addr_cntr_d = column_addr_cntr_q;
       ready_o = 1'b0;
       en_hamming_cntrs = 1'b0;
       clr_hamming_cntrs = 1'b0;
       valid_o = 1'b0;
       unique case (state_q)
         Idle: begin
           ready_o = 1'b1;
           if (start_i==1'b1) begin
             clr_hamming_cntrs = 1'b1;
             state_d = Busy;
             ready_o = 1'b0;
           end
         end

         Busy: begin
           en_hamming_cntrs = 1'b1;
           if (column_addr_cntr_q == MEM_ROW_WIDTH-1) begin
             //Finished calculation
             state_d = Done;
             column_addr_cntr_d = '0;
           end else begin
             //Process next component (column).
             column_addr_cntr_d++;
           end
         end

         Done: begin
           valid_o     = 1'b1;
           if (start_i == 1'b0) begin
             state_d = Idle;
           end else begin
             state_d = Done;
           end
         end
         default :
           //Go to legal state
           state_d = Idle;
       endcase
     end


   //--------------------- Hamming counters ---------------------
   always_comb
     begin
       hamming_cntrs_d = hamming_cntrs_q;
       for (int unsigned row_idx = 0; row_idx<ROW_CNT-ROWS_PER_HDVECT; row_idx++) begin
         if (clr_hamming_cntrs == 1'b1)
           hamming_cntrs_d = '{default:'0};
         else
           if (en_hamming_cntrs == 1'b1) begin
             if (search_vector[row_idx%ROWS_PER_HDVECT] ^ column_i[row_idx] == 1'b1)
               hamming_cntrs_d[row_idx] = hamming_cntrs_q[row_idx]+1;
           end
       end
     end // always_comb


   //----------------- Sum of Hamming counters -----------------
   always_comb
     begin
       for (int unsigned vector_idx = 0; vector_idx<VECTOR_CNT-1; vector_idx++) begin
         hamming_distances[vector_idx] = 0;
         for (int unsigned row_idx = 0; row_idx<ROWS_PER_HDVECT; row_idx++) begin
           hamming_distances[vector_idx] += hamming_cntrs_q[vector_idx*ROWS_PER_HDVECT+row_idx];
         end
       end
     end

   //----------------------- Comparators -----------------------
   always_comb
     begin
       hamming_distance_t min_hamming_distance; 
       vector_idx_t min_index;
       min_hamming_distance = '1;
       min_index = 0;
       for (int unsigned vector_idx = 0; vector_idx<VECTOR_CNT-1; vector_idx++) begin
         if (hamming_distances[vector_idx]<min_hamming_distance) begin
           min_hamming_distance = hamming_distances[vector_idx];
           min_index            = vector_idx;
         end
       end
       result_idx_o   = min_index;
       min_distance_o = min_hamming_distance;
     end

   //--------------------- Sequential logic ---------------------
   always_ff @(posedge clk_i, negedge rst_ni)
     begin
       if (!rst_ni) begin
         state_q            <= Idle;
         hamming_cntrs_q    <= '{default:'0};
         column_addr_cntr_q <= '0;
       end else begin
         state_q            <= state_d;
         hamming_cntrs_q    <= hamming_cntrs_d;
         column_addr_cntr_q <= column_addr_cntr_d;
       end
     end
endmodule : am_search_unit

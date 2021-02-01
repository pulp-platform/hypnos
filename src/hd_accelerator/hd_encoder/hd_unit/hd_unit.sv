//-----------------------------------------------------------------------------
// Title         : HD-unit
//-----------------------------------------------------------------------------
// File          : hd_unit.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 26.09.2018
//-----------------------------------------------------------------------------
// Description :
// This module processes a single component of the input vector by performing one
// of the available HD-operations (shift, bundle, bind, passthrough). It contains
// an output flip-flop for write back of the result to SCM and to perform binary 
// operators on an input vector from SCM and the result of the previous operation
// stored in the flip-flop.
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

module hd_unit
  import pkg_common::*;
  import pkg_hd_unit::*;
  (
    input logic            clk_i,
    input logic            rst_ni,
    input logic            bit_i,
    input operand_sel_e    sel_op_i,
    input logic            en_bundle_cntr_i,
    input logic            rst_bundle_cntr_i,
    input logic            bit_right_i,
    input logic            bit_left_i,
    input logic            bundle_ctx_we_i,
    input logic            bundle_ctx_add_i,
    input bundle_ctx_idx_t bundle_ctx_idx_i,
    output logic           result_bit_o
    );

  logic                                operand_a;
  logic                                operand_b;
  logic                                bind_result;
  logic                                bundle_result;
  logic                                result_d, result_q;
  logic signed [BUNDLE_CNTR_WIDTH-1:0] counter_d, counter_q; //5 bit counter for bundling


  //operand_a is the input bit (could be row from hd-memory or the feedback from hd_unit's output depending on toplevel's multiplexers)
  assign operand_a = bit_i;

  //Operand b is always the output of the result flip-flop. Dedicated signal only for clarity
  assign operand_b = result_q;

  //result mux
  always_comb begin
    unique case(sel_op_i)
      PASSTHROUGH:
        result_d = operand_a;
      AND:
        result_d = operand_a & operand_b;
      BIND:
        result_d = operand_a ^ operand_b;
      BUNDLE:
        result_d = counter_q[BUNDLE_CNTR_WIDTH-1]; //MSB is the sign bit. If an even number of vectors where bundled the result is biased towards 1;
      SHIFT_RIGHT:
        result_d = bit_left_i;
      SHIFT_LEFT:
        result_d = bit_right_i;
      NOP:
        result_d = result_q;
      BUNDLE_CTX:
        result_d = counter_q[bundle_ctx_idx_i];
      default: begin
        result_d = 'x;
      end
    endcase
  end

  //Bundling counters
  always_comb begin
    if (rst_bundle_cntr_i == 1'b1) begin
      counter_d = '0;
    end else if (bundle_ctx_we_i) begin
      counter_d                   = counter_q;
      counter_d[bundle_ctx_idx_i] = bit_i;
    end else if (bundle_ctx_add_i) begin
      counter_d = counter_q + (bit_i<<bundle_ctx_idx_i);
      //Detect over-/underflows. Assumes that the MSB of the old value of
      //counter_q was stored in result_q beforehand. (sel_op_i == BUNDLE). In
      //case of over-/underflow the counter saturates.
      if ((bundle_ctx_idx_i == (BUNDLE_CNTR_WIDTH-1)) && bit_i == result_q && bit_i != counter_d[BUNDLE_CNTR_WIDTH-1]) begin
        counter_d[BUNDLE_CNTR_WIDTH-1] = result_q;
        for (int i = 0; i < BUNDLE_CNTR_WIDTH-1; i++) begin
          counter_d[i] = ~result_q;
        end
      end
    end else if (en_bundle_cntr_i == 1'b1) begin
      if (result_d == 0) begin
        if (counter_q == signed'(2**(BUNDLE_CNTR_WIDTH-1)-1)) begin
          counter_d = counter_q; //Saturate
        end else begin
          counter_d = counter_q+1;
        end
      end else begin
        if (counter_q == -signed'(2**(BUNDLE_CNTR_WIDTH-1))) begin
          counter_d = counter_q; //Saturate
        end else begin
          counter_d = counter_q-1;
        end
      end
    end else begin
      counter_d =counter_q;
    end
  end

  //Output assignments
  assign result_bit_o = result_q;

  //Flip-flops
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (rst_ni == 1'b0) begin
      result_q <= '0;
      counter_q <= '0;
    end else begin
      result_q <= result_d;
      counter_q <= counter_d;
    end
  end
endmodule : hd_unit

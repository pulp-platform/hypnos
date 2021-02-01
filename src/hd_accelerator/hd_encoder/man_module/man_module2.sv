//-----------------------------------------------------------------------------
// Title         : MAN Module Alternative
//-----------------------------------------------------------------------------
// File          : man_module2.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 19.10.2018
//-----------------------------------------------------------------------------
// Description :
// Alternative implementation of the MAN module according to idea of Luca Benini.
// The mask hypervectors are not generated but hardwired with ti-hilo cells and
// a multiplexer per component that selects one of the seed vectors.
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
   import pkg_seeds::seeds;
   #(localparam VALUE_WIDTH = 7,
     localparam VEC_WIDTH = 1024)
   (
    input logic [VALUE_WIDTH-1:0] value_i,
    input logic [VEC_WIDTH-1:0]   vector_i,
    output logic [VEC_WIDTH-1:0]  vector_o
    );

   assign vector_o = seeds[value_i] ^ vector_i;

endmodule

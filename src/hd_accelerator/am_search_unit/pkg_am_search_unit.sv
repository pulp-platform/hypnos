//-----------------------------------------------------------------------------
// Title         : Typedefs and parameters for AM Search Unit
//-----------------------------------------------------------------------------
// File          : pkg_am_search_unit.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 18.09.2018
//-----------------------------------------------------------------------------
// Description :
//
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

package pkg_am_search_unit;
   import pkg_common::*;

   localparam COUNTER_WIDTH = $clog2(MEM_ROW_WIDTH)+1; //Otherwise completely anticorellated rows will overflow the hamming distance counter.


endpackage : pkg_am_search_unit

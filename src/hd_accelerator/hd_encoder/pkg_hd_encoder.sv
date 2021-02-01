//-----------------------------------------------------------------------------
// Title         : Package HD-encoder
//-----------------------------------------------------------------------------
// File          : pkg_hd_encoder.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 01.10.2018
//-----------------------------------------------------------------------------
// Description :
// This package contains typedefs for select signal enums and other control signals
// used in the hd_encoder and other modules.
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
package pkg_hd_encoder;
   typedef enum logic[1:0] {OUTPUT_REG, MEMORY, ZERO} input_sel_t;
   typedef enum logic[0:0] {EXTERNAL, INTERNAL} man_value_sel_t;
endpackage : pkg_hd_encoder

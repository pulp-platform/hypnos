//-----------------------------------------------------------------------------
// Title         : HD-unit Package
//-----------------------------------------------------------------------------
// File          : pkg_hd_unit.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 26.09.2018
//-----------------------------------------------------------------------------
// Description :
// This package contains typedefinitions used to interact with the hd_unit module.
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

package pkg_hd_unit;
  typedef enum logic[2:0] {PASSTHROUGH, BIND, BUNDLE, BUNDLE_CTX, AND, SHIFT_RIGHT, SHIFT_LEFT, NOP} operand_sel_e;
  typedef logic [$clog2(pkg_common::BUNDLE_CNTR_WIDTH)-1:0] bundle_ctx_idx_t;
endpackage : pkg_hd_unit

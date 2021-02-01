
//-----------------------------------------------------------------------------
// Title         : Memory Mapping Package
//-----------------------------------------------------------------------------
// File          : pkg_memory_mapping.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 11.10.2018
//-----------------------------------------------------------------------------
// Description :
// This package contains the memory mapping addresses used in the debug unit.
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

package pkg_memory_mapping;
  parameter CONFIG_ADDR_WIDTH = 16;
  typedef logic[CONFIG_ADDR_WIDTH-1:0] cfg_addr_t;

  ///////////////////////////////////////////////////////////
  //                       _                _              //
  //     /\               | |              | |             //
  //    /  \   ___ ___ ___| | ___ _ __ __ _| |_ ___  _ __  //
  //   / /\ \ / __/ __/ _ \ |/ _ \ '__/ _` | __/ _ \| '__| //
  //  / ____ \ (_| (_|  __/ |  __/ | | (_| | || (_) | |    //
  // /_/    \_\___\___\___|_|\___|_|  \__,_|\__\___/|_|    //
  ///////////////////////////////////////////////////////////
  //------------- Program Counter/HW-loop module --------------
  parameter logic [15:12]              PC_BASE_ADDR              = 4'h0;
  parameter logic [11:0]               PC_REG                    = 12'h000;
  localparam cfg_addr_t                ADDR_PC_REG               = {PC_BASE_ADDR, PC_REG};
  //------------------------ HD-memory ------------------------
  parameter logic [15:12]              HD_MEM_BASE_ADDR          = 4'h1;
  localparam cfg_addr_t                ADDR_HD_MEM_START         = {HD_MEM_BASE_ADDR, 16'b0};
  //----------------- Shared Memory Interface -----------------
  parameter logic [15:12]              SMI_BASE_ADDR             = 4'h2;
  parameter logic [11:0]               SMI_RADDR_REG             = 12'h000;
  localparam cfg_addr_t                ADDR_SMI_RADDR_REG        = {SMI_BASE_ADDR, SMI_RADDR_REG};
  parameter logic [11:0]               SMI_RADDR_STRIDE_REG      = 12'h004;
  localparam cfg_addr_t                ADDR_SMI_RADDR_STRIDE_REG = {SMI_BASE_ADDR, SMI_RADDR_STRIDE_REG};
  parameter logic [11:0]               SMI_WADDR_REG             = 12'h008;
  localparam cfg_addr_t                ADDR_SMI_WADDR_REG        = {SMI_BASE_ADDR, SMI_WADDR_REG};
  parameter logic [11:0]               SMI_WADDR_STRIDE_REG      = 12'h00C;
  localparam cfg_addr_t                ADDR_SMI_WADDR_STRIDE_REG = {SMI_BASE_ADDR, SMI_WADDR_STRIDE_REG};
  //-------------------- Instruction Memory --------------------
  parameter logic [15:12]              IM_BASE_ADDR              = 4'h3;
  localparam cfg_addr_t                ADDR_IM_START             = {IM_BASE_ADDR, 16'b0};
  //---------------------- Offset Counter ----------------------
  parameter logic [15:12]              OFFSET_CNTR_BASE_ADDR     = 4'h4;
  parameter logic [11:0]               OFFSET_CNTR_REG           = 12'h000;
  localparam cfg_addr_t                ADDR_OFFSET_CNTR_REG      = {OFFSET_CNTR_BASE_ADDR, OFFSET_CNTR_REG};
  //------------------ Internal MAN-value reg ------------------
  parameter logic [15:12]              INT_MAN_BASE_ADDR         = 4'h5;
  parameter logic [11:0]               INT_MAN_REG               = 12'h000;
  localparam cfg_addr_t                ADDR_INT_MAN_REG          = {INT_MAN_BASE_ADDR, INT_MAN_REG};
  //-------------- Instruction Decoder Enable Reg --------------
  parameter logic [15:12]              DEC_EN_BASE_ADDR          = 4'h6;
  parameter logic [11:0]               DEC_EN_REG                = 12'h000;
  localparam cfg_addr_t                ADDR_DEC_EN               = {DEC_EN_BASE_ADDR, DEC_EN_REG};
  //------------------- Next Instruction -------------------
  parameter logic [15:12]              NXT_INSTR_BASE_ADDR       = 4'h7;
  parameter logic [11:0]               NXT_INSTR_REG             = 12'h000;
  localparam cfg_addr_t                ADDR_NXT_INSTR_REG        = {NXT_INSTR_BASE_ADDR, NXT_INSTR_REG};
  //--------------------- Result Registers ---------------------
  parameter logic [15:12]              RESULT_REG_BASE_ADDR      = 4'h8;
  parameter logic [11:0]               RESULT_REG_IDX            = 12'h000;
  localparam cfg_addr_t                ADDR_RESULT_REG_IDX       = {RESULT_REG_BASE_ADDR, RESULT_REG_IDX};
  parameter logic [11:0]               RESULT_REG_DISTANCE       = 12'h004;
  localparam cfg_addr_t                ADDR_RESULT_REG_DISTANCE  = {RESULT_REG_BASE_ADDR, RESULT_REG_DISTANCE};
  //-------------------- Interrupt Register --------------------
  parameter logic [15:12]              INTERRUPT_REG_BASE_ADDR   = 4'h9;
  parameter logic [11:0]               INTERRUPT_REG_IDX         = 12'h000;
  localparam cfg_addr_t                ADDR_INTERRUPT_REG_IDX = {NXT_INSTR_BASE_ADDR, NXT_INSTR_REG};


  //////////////////////////////////////////////////////////
  //   _____ _____ _____   __  __           _             //
  //  / ____|  __ \_   _| |  \/  |         | |            //
  // | (___ | |__) || |   | \  / | __ _ ___| |_ ___ _ __  //
  //  \___ \|  ___/ | |   | |\/| |/ _` / __| __/ _ \ '__| //
  //  ____) | |    _| |_  | |  | | (_| \__ \ ||  __/ |    //
  // |_____/|_|   |_____| |_|  |_|\__,_|___/\__\___|_|    //
  //////////////////////////////////////////////////////////

  //--------------------- Config Registers ---------------------
  parameter logic [15:12]              SPIM_BASE_ADDR         = 4'ha;
  parameter logic [11:0]               SPIM_IM_START          = 12'h000;
  parameter logic [11:0]               SPIM_IM_END            = 12'h0ff;
  parameter logic [11:0]               SPIM_REG_ENABLE        = 12'h100;
  parameter logic [11:0]               SPIM_REG_STATUS        = 12'h200;
  parameter logic [11:0]               SPIM_REG_PROG_SIZE     = 12'h300;
  parameter logic [11:0]               SPIM_REG_RX_DATA       = 12'h400;
  parameter logic [11:0]               SPIM_REG_CLR_INTRPT = 12'h500;

  ///////////////////////////////////////////////////////////////////
  //  _____                                                        //
  // |  __ \                                                       //
  // | |__) | __ ___ _ __  _ __ ___   ___ ___  ___ ___  ___  _ __  //
  // |  ___/ '__/ _ \ '_ \| '__/ _ \ / __/ _ \/ __/ __|/ _ \| '__| //
  // | |   | | |  __/ |_) | | | (_) | (_|  __/\__ \__ \ (_) | |    //
  // |_|   |_|  \___| .__/|_|  \___/ \___\___||___/___/\___/|_|    //
  //                | |                                            //
  //                |_|                                            //
  ///////////////////////////////////////////////////////////////////

  parameter logic [15:12]              PREPROC_BASE_ADDR             = 4'hb;
  parameter logic [11:0]               PREPROC_CHN_CFG_REG_START     = 12'h000;
  parameter logic [11:0]               PREPROC_CHN_CFG_REG_END       = 12'h0ff;
  parameter logic [11:0]               PREPROC_CHN_PRE_OFFSET_START  = 12'h100;
  parameter logic [11:0]               PREPROC_CHN_PRE_OFFSET_END    = 12'h1ff;
  parameter logic [11:0]               PREPROC_CHN_POST_OFFSET_START = 12'h200;
  parameter logic [11:0]               PREPROC_CHN_POST_OFFSET_END   = 12'h2ff;
  parameter logic [11:0]               PREPROC_REG_SUBSAMPLING       = 12'h300;
  parameter logic [11:0]               PREPROC_REG_SOFT_RESET        = 12'h304;

  ////////////////////////////////////////////////////////
  //  _____ ____          _____             __ _        //
  // |_   _/ __ \        / ____|           / _(_)       //
  //   | || |  | |______| |     ___  _ __ | |_ _  __ _  //
  //   | || |  | |______| |    / _ \| '_ \|  _| |/ _` | //
  //  _| || |__| |      | |___| (_) | | | | | | | (_| | //
  // |_____\____/        \_____\___/|_| |_|_| |_|\__, | //
  //                                              __/ | //
  //                                             |___/  //
  ////////////////////////////////////////////////////////

  parameter logic [15:12]              IO_CONFIG_BASE_ADDR = 4'hc;
  parameter logic [11:0]               IO_CONFIG_REG_START = 12'h000; //IO-pad[1] = 12'h004 etc.

endpackage : pkg_memory_mapping

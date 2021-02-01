//-----------------------------------------------------------------------------
// Title         : Common parameter and type definitions
//-----------------------------------------------------------------------------
// File          : pkg_common.sv
// Author        : Manuel Eggimann  <meggiman@blitzstein.ee.ethz.ch>
// Created       : 17.09.2018
//-----------------------------------------------------------------------------
// Description :
// This package provides typedefs and parameters used throughout the whole architecture
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
package pkg_common;

//////////////////////////////////////////////////////////////////////////////
//  _    _ _____                            _                _              //
// | |  | |  __ \         /\               | |              | |             //
// | |__| | |  | |______ /  \   ___ ___ ___| | ___ _ __ __ _| |_ ___  _ __  //
// |  __  | |  | |______/ /\ \ / __/ __/ _ \ |/ _ \ '__/ _` | __/ _ \| '__| //
// | |  | | |__| |     / ____ \ (_| (_|  __/ |  __/ | | (_| | || (_) | |    //
// |_|  |_|_____/     /_/    \_\___\___\___|_|\___|_|  \__,_|\__\___/|_|    //
//////////////////////////////////////////////////////////////////////////////

`ifdef DIMENSIONS
  parameter DIMENSIONS = `DIMENSIONS;
`else
  parameter DIMENSIONS = 2048; //power of two
`endif

`ifdef MEM_ROW_WIDTH
  parameter MEM_ROW_WIDTH = `MEM_ROW_WIDTH;
`else
  parameter MEM_ROW_WIDTH = 2048; //< DIMENSION/2, power of two
`endif

`ifdef WORD_WIDTH
  parameter WORD_WIDTH = `WORD_WIDTH;
`else
  parameter WORD_WIDTH = 32; //<= MEM_ROW_WIDTH/2, power of two
`endif

`ifdef ROW_CNT
  parameter ROW_CNT = `ROW_CNT;
`else
  parameter ROW_CNT = 32;
`endif

`ifdef BUNDLE_CNTR_WIDTH
  parameter BUNDLE_CNTR_WIDTH = `BUNDLE_CNTR_WIDTH;
`else
  parameter BUNDLE_CNTR_WIDTH = 8;
`endif

`ifdef QUANTIZATION_LEVELS
  parameter QUANTIZATION_LEVELS = `QUANTIZATION_LEVELS;
`else
  parameter QUANTIZATION_LEVELS = 128; //<= MEM_ROW_WIDTH/2
`endif

`ifdef IM_ROW_CNT
  parameter IM_ROW_CNT = `IM_ROW_CNT;
`else
  parameter IM_ROW_CNT = 64;
`endif

`ifdef SHARED_MEM_ADDR_WIDTH
  parameter SHARED_MEM_ADDR_WIDTH = `SHARED_MEM_ADDR_WIDTH;
`else
  parameter SHARED_MEM_ADDR_WIDTH = 32;
`endif

`ifdef SHARED_MEM_STRIDE_WIDTH
  parameter SHARED_MEM_STRIDE_WIDTH = `SHARED_MEM_STRIDE_WIDTH;
`else
  parameter SHARED_MEM_STRIDE_WIDTH = 8;
`endif

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
`ifdef PREPROC_NR_CHANNELS
  parameter PREPROC_NR_CHANNELS = `PREPROC_NR_CHANNELS;
`else
  parameter PREPROC_NR_CHANNELS = 8;
`endif

`ifdef PREPROC_DATA_WIDTH
  parameter PREPROC_DATA_WIDTH = `PREPROC_DATA_WIDTH;
`else
  parameter PREPROC_DATA_WIDTH = 16;
`endif

`ifdef PREPROC_ALPHA_WDITH
  parameter PREPROC_ALPHA_WDITH = `PREPROC_ALPHA_WDITH;
`else
  parameter PREPROC_ALPHA_WDITH = 8;
`endif

`ifdef PREPROC_LBP_CODESIZE
  parameter PREPROC_LBP_CODESIZE = `PREPROC_LBP_CODESIZE;
`else
  parameter PREPROC_LBP_CODESIZE = 6;
`endif

`ifdef PREPROC_FIFO_DEPTH
  parameter PREPROC_FIFO_DEPTH = `PREPROC_FIFO_DEPTH;
`else
  parameter PREPROC_FIFO_DEPTH = 4;
`endif

`ifdef PREPROC_SUBSAMPLING_WIDTH
  parameter PREPROC_SUBSAMPLING_WIDTH = `PREPROC_SUBSAMPLING_WIDTH;
`else
  parameter PREPROC_SUBSAMPLING_WIDTH = 16;
`endif

/////////////////////////////////////////////////h//////////////////////////////
//  _____            _               _   _____                               //
// |  __ \          (_)             | | |  __ \                              //
// | |  | | ___ _ __ ___   _____  __| | | |__) |_ _ _ __ __ _ _ __ ___  ___  //
// | |  | |/ _ \ '__| \ \ / / _ \/ _` | |  ___/ _` | '__/ _` | '_ ` _ \/ __| //
// | |__| |  __/ |  | |\ V /  __/ (_| | | |  | (_| | | | (_| | | | | | \__ \ //
// |_____/ \___|_|  |_| \_/ \___|\__,_| |_|   \__,_|_|  \__,_|_| |_| |_|___/ //
///////////////////////////////////////////////////////////////////////////////
//  Don't change me                                                          //
///////////////////////////////////////////////////////////////////////////////


  //------------------------ HD-memory ------------------------
  localparam MEM_ADDR_WIDTH    = $clog2(ROW_CNT);
  localparam WORD_ADDR_WIDTH   = MEM_ADDR_WIDTH+$clog2(MEM_ROW_WIDTH/WORD_WIDTH);
  localparam WORD_CNT          = 2**WORD_ADDR_WIDTH;
  localparam COLUMN_ADDR_WIDTH = $clog2(MEM_ROW_WIDTH);
  localparam WORDS_PER_ROW     = MEM_ROW_WIDTH/WORD_WIDTH;
  localparam ROWS_PER_HDVECT   = DIMENSIONS/MEM_ROW_WIDTH;
  localparam VECTOR_CNT        = ROW_CNT/ROWS_PER_HDVECT;
  localparam VECTOR_IDX_WIDTH  = $clog2(VECTOR_CNT);
  localparam MAN_VALUE_WIDTH   = $clog2(QUANTIZATION_LEVELS);
  typedef logic [WORD_WIDTH-1:0] word_t;
  typedef logic [VECTOR_IDX_WIDTH-1:0]  vector_idx_t;
  typedef struct                        packed {
    logic [MEM_ADDR_WIDTH-1:0]          row_addr;
    logic [$clog2(MEM_ROW_WIDTH/WORD_WIDTH)-1:0] word_addr;
  } addr_t;
  typedef union                                  packed {
    logic [MEM_ROW_WIDTH-1:0]                    row;
    word_t [0:WORDS_PER_ROW-1]                   words;
  } row_t;

  //------------------------ HD-Encoder ------------------------
  localparam HAMMING_DISTANCE_WIDTH = $clog2(DIMENSIONS)+1;
  typedef logic [MAN_VALUE_WIDTH-1:0]            man_value_t;
  typedef logic [HAMMING_DISTANCE_WIDTH-1:0]     hamming_distance_t;

  //--------------------- uCode Sequencer ---------------------
  localparam IM_ADDR_WIDTH = $clog2(IM_ROW_CNT);
  typedef logic [IM_ADDR_WIDTH-1:0]              im_addr_t;

  //-------------------- PC/HW loop engine --------------------
  localparam HWL_REGS_CNT  = 3;
  localparam HWL_CNTR_WITH = 10;
  localparam HWL_SEL_WIDTH = $clog2(HWL_REGS_CNT);
  typedef logic [HWL_CNTR_WITH-1:0]              hwl_iterations_t;

  //----------------- Shared Memory Interface -----------------
  typedef logic [SHARED_MEM_ADDR_WIDTH-1:0]      shared_mem_addr_t;
  typedef logic [SHARED_MEM_STRIDE_WIDTH-1:0]    shared_mem_stride_t;


endpackage : pkg_common

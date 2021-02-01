// -----------------------------------------------------------------------------
// Title      : Config Interface
// Project    : HD-Accelerator for Vega
// -----------------------------------------------------------------------------
// File       : cfg_iface.sv
// Author     : Manuel Eggimann <meggimann@iis.ee.ethz.ch>
// Company    : Integrated Systems Laboratory, ETH Zurich
// Created    : 20.02.2019
// -----------------------------------------------------------------------------
// Description: Asynchronous interface between the acclerator and the rest of
//              the chip. Uses 4-way handshaking for clock-domain crossing
//              according to the protocol specified for David Bellasi's FLL.
//-----------------------------------------------------------------------------
// SPDX-License-Identifier: SHL-0.51
// Copyright (C) 2018-2021 ETH Zurich, University of Bologna
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//-----------------------------------------------------------------------------

module cfg_iface

  import pkg_common::*;
  import pkg_memory_mapping::*;
(
 //Reset
 input logic       rst_ni,
 //External SoC Interface (asynchronous)
 input logic       CFGREQ,
 input word_t      CFGD,
 input cfg_addr_t  CFGAD,
 input logic       CFGWEB,
 output word_t     CFGQ,
 output logic      CFGACK,
 //Accelerator Interface (synchronized with system clock)
 input logic       clk_i, //Accelerator System Clock
 output logic      accl_cfg_req_o,
 input logic       accl_cfg_gnt_i,
 output logic      accl_cfg_wen_o,
 output cfg_addr_t accl_cfg_addr_o,
 output word_t     accl_cfg_wdata_o,
 input word_t      accl_cfg_rdata_i,
 input logic       accl_cfg_rvalid_i,

 //SPI Master Config Interface
 output logic      spim_cfg_req_o,
 input logic       spim_cfg_gnt_i,
 output logic      spim_cfg_we_o,
 output cfg_addr_t spim_cfg_addr_o,
 output word_t     spim_cfg_wdata_o,
 input word_t      spim_cfg_rdata_i,
 input logic       spim_cfg_rvalid_i,

 //Preprocessor Config Interface
 output logic      preproc_cfg_req_o,
 input logic       preproc_cfg_gnt_i,
 output logic      preproc_cfg_we_o,
 output cfg_addr_t preproc_cfg_addr_o,
 output word_t     preproc_cfg_wdata_o,
 input word_t      preproc_cfg_rdata_i,
 input logic       preproc_cfg_rvalid_i,

 //IO Config Interface
 output logic      io_cfg_req_o,
 input logic       io_cfg_gnt_i,
 output logic      io_cfg_we_o,
 output cfg_addr_t io_cfg_addr_o,
 output word_t     io_cfg_wdata_o,
 input word_t      io_cfg_rdata_i,
 input logic       io_cfg_rvalid_i
);

  typedef enum logic [1:0]     {Idle, Sens, Ack} cfg_state_e;

  //------------------------ Registers ------------------------
  cfg_state_e      cfg_state_d, cfg_state_q;
  logic [1:0]      CFGREQ_d,    CFGREQ_q;
  cfg_addr_t       CFGAD_d,     CFGAD_q;
  logic            CFGWEB_d,    CFGWEB_q;
  word_t           CFGD_d,      CFGD_q;
  word_t           CFGQ_d,      CFGQ_q;

  //------------------- Request Synchronizer -------------------
  assign CFGREQ_d = {CFGREQ_q[0], CFGREQ};

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      CFGREQ_q <= '0;
    end else begin
      CFGREQ_q <= CFGREQ_d;
    end
  end

  //----------------------- IO Registers -----------------------
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      CFGAD_q  <= '0;
      CFGWEB_q <= 1'b1;
      CFGD_q   <= '0;
      CFGQ_q   <= '0;
    end else begin
      CFGAD_q  <= CFGAD_d;
      CFGWEB_q <= CFGWEB_d;
      CFGD_q   <= CFGD_d;
      CFGQ_q   <= CFGQ_d;
    end
  end // always_ff @ (posedge REFCLK, negedge rst_ni)

  //---------------------- Handshake FSM ----------------------
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      cfg_state_q <= Idle;
    end else begin
      cfg_state_q <= cfg_state_d;
    end
  end

  always_comb begin
    //Default assignments
    cfg_state_d       = cfg_state_q;
    CFGAD_d           = CFGAD_q;
    CFGWEB_d          = CFGWEB_q;
    CFGD_d            = CFGD_q;
    CFGQ_d            = CFGQ_q;

    CFGACK            = 1'b0;
    accl_cfg_req_o    = 1'b0;
    accl_cfg_wen_o     = 1'b1;
    spim_cfg_req_o    = 1'b0;
    spim_cfg_we_o     = 1'b0;
    io_cfg_req_o      = 1'b0;
    io_cfg_we_o       = 1'b0;
    preproc_cfg_req_o = 1'b0;
    preproc_cfg_we_o  = 1'b0;


    case (cfg_state_q)
      Idle: begin
        if (CFGREQ_q[1]) begin // New request
          cfg_state_d = Sens;
          CFGAD_d     = CFGAD;
          CFGWEB_d    = CFGWEB;
          CFGD_d      = CFGD;
        end
      end

      Sens: begin
        if (CFGREQ_q[1]) begin
          case (CFGAD_q[15:12])
            SPIM_BASE_ADDR: begin
              // SPI Master Config request
              if (CFGWEB_q == 1'b0) begin
                // Write Request
                spim_cfg_req_o = 1'b1;
                spim_cfg_we_o  = 1'b1;
                if (spim_cfg_gnt_i == 1'b1) begin
                  // Grant received
                  cfg_state_d = Ack;
                end
              end else begin
                //Read Request
                spim_cfg_req_o        = 1'b1;
                if (spim_cfg_rvalid_i == 1'b1) begin
                  CFGQ_d              = spim_cfg_rdata_i;
                  cfg_state_d         = Ack;
                end
              end // else: !if(CFGWEB_q == 1'b0)
            end // case: SPIM_BASE_ADDR

            IO_CONFIG_BASE_ADDR: begin
              // IO Pad Config request
              if (CFGWEB_q == 1'b0) begin
                // Write Request
                io_cfg_req_o = 1'b1;
                io_cfg_we_o  = 1'b1;
                if (io_cfg_gnt_i == 1'b1) begin
                  // Grant received
                  cfg_state_d = Ack;
                end
              end else begin
                //Read Request
                io_cfg_req_o        = 1'b1;
                if (io_cfg_rvalid_i == 1'b1) begin
                  CFGQ_d              = io_cfg_rdata_i;
                  cfg_state_d         = Ack;
                end
              end // else: !if(CFGWEB_q == 1'b0)
            end // case: IO_CONFIG_BASE_ADDR

            PREPROC_BASE_ADDR: begin
              // Preprocessor Config request
              if (CFGWEB_q == 1'b0) begin
                // Write Request
                preproc_cfg_req_o = 1'b1;
                preproc_cfg_we_o  = 1'b1;
                if (preproc_cfg_gnt_i == 1'b1) begin
                  // Grant received
                  cfg_state_d = Ack;
                end
              end else begin
                //Read Request
                preproc_cfg_req_o        = 1'b1;
                if (preproc_cfg_rvalid_i == 1'b1) begin
                  CFGQ_d              = preproc_cfg_rdata_i;
                  cfg_state_d         = Ack;
                end
              end // else: !if(CFGWEB_q == 1'b0)
            end

            default: begin //Forward other requests to accelerator
              // Accelerator Config Request
              if (CFGWEB_q == 1'b0) begin
                // Write Request
                accl_cfg_req_o = 1'b1;
                accl_cfg_wen_o  = 1'b0;
                if (accl_cfg_gnt_i == 1'b1) begin
                  // Grant received
                  cfg_state_d = Ack;
                end
              end else begin
                // Read Request
                accl_cfg_req_o = 1'b1;
                if (accl_cfg_rvalid_i == 1'b1) begin
                  CFGQ_d            = accl_cfg_rdata_i;
                  cfg_state_d = Ack;
                end
              end // else: !if(CFGWEB_q == 1'b0)
            end // case: default
          endcase
        end else begin
          cfg_state_d = Idle;
        end
      end // case: Sens

      Ack: begin
        CFGACK          = 1'b1;
        //Wait until synchronized request flag goes low before deasserting ack
        if (CFGREQ_q[1] == 1'b0) begin
          cfg_state_d = Idle;
        end else begin
          cfg_state_d = Ack;
        end
      end
      default: begin
        cfg_state_d = Idle;
      end
    endcase
  end // always_comb

  //-------------------- Static Assignments --------------------
  assign accl_cfg_wdata_o    = CFGD_q;
  assign spim_cfg_wdata_o    = CFGD_q;
  assign io_cfg_wdata_o      = CFGD_q;
  assign preproc_cfg_wdata_o = CFGD_q;

  assign accl_cfg_addr_o     = CFGAD_q;
  assign spim_cfg_addr_o     = CFGAD_q;
  assign io_cfg_addr_o       = CFGAD_q;
  assign preproc_cfg_addr_o  = CFGAD_q;

  assign CFGQ = CFGQ_q;

endmodule : cfg_iface

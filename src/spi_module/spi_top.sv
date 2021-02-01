//-----------------------------------------------------------------------------
// Title : SPI TOP
// -----------------------------------------------------------------------------
// File : spi_top.sv Author : Manuel Eggimann <meggimann@iis.ee.ethz.ch> Created
// : 07.03.2019
// -----------------------------------------------------------------------------
// Description : A stripped down version of the udma_qspi module with all the
// udma related components removed.
//-----------------------------------------------------------------------------
// SPDX-License-Identifier: SHL-0.51
// Copyright (C) 2013-2021 ETH Zurich, University of Bologna
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//-----------------------------------------------------------------------------

module spi_top
  import pkg_memory_mapping::*;
  #(
    parameter REPLAY_BUFFER_DEPTH = 6,
    parameter CMD_MEM_SIZE = 16,
    localparam CMD_MEM_ADDR_WIDTH = $clog2(CMD_MEM_SIZE)
    )
  (
   input logic         clk_i,
   input logic         rst_ni,
   input logic         dft_test_mode_i,
   input logic         dft_cg_enable_i,

   output logic        cs_clear_evt_o, //Optional event triggered by the chip select
                                                       //clear command
   input logic         cfg_req_i,
   output logic        cfg_gnt_o,
   input logic         cfg_we_i,
   input logic [11:0]  cfg_addr_i,
   input logic [31:0]  cfg_wdata_i,
   output logic [31:0] cfg_rdata_o,
   output logic        cfg_rvalid_o,

   output logic [31:0] data_rx_o,
   output logic        data_rx_valid_o,
   input logic         data_rx_ready_i,

   output logic        spi_clk_o,
   output logic        spi_csn0_o,
   output logic        spi_csn1_o,
   output logic        spi_csn2_o,
   output logic        spi_csn3_o,
   output logic        spi_oen0_o,
   output logic        spi_oen1_o,
   output logic        spi_oen2_o,
   output logic        spi_oen3_o,
   output logic        spi_sdo0_o,
   output logic        spi_sdo1_o,
   output logic        spi_sdo2_o,
   output logic        spi_sdo3_o,
   input logic         spi_sdi0_i,
   input logic         spi_sdi1_i,
   input logic         spi_sdi2_i,
   input logic         spi_sdi3_i
  );



  ////////////////////////////////////////
  //   _____ _                   _      //
  //  / ____(_)                 | |     //
  // | (___  _  __ _ _ __   __ _| |___  //
  //  \___ \| |/ _` | '_ \ / _` | / __| //
  //  ____) | | (_| | | | | (_| | \__ \ //
  // |_____/|_|\__, |_| |_|\__,_|_|___/ //
  //            __/ |                   //
  //           |___/                    //
  ////////////////////////////////////////

  ///////////////
  // SPI Clock //
  ///////////////
  logic        s_clk_spi;

  ////////////////////////////////////
  // SPIM Controller => CLK Divider //
  ////////////////////////////////////
  logic [7:0]  ctrl_clkdiv_data;
  logic        ctrl_clkdiv_valid;

  /////////////////////////////////////////
  // SPIM Controller => Config Interface //
  /////////////////////////////////////////
  logic [4:0]  ctrl_cfgif_status;

  ///////////////////////////
  // SPIM Controller <=> * //
  ///////////////////////////
  logic [31:0] ctrl_rx_data;
  logic        ctrl_rx_valid;

  ////////////////////////////////////
  // CLK Divider => SPIM Controller //
  ////////////////////////////////////
  logic        clkdiv_ctrl_ack;

  /////////////////////////////////////
  // Config Interface => CLK Divider //
  /////////////////////////////////////
  logic        cfgif_clkdiv_en;

  ////////////////////////////////////
  // Config Interface => Controller //
  ////////////////////////////////////
  logic        cfgif_ctrl_rx_ready;
  logic        cfgif_ctrl_trigger_evt;

  ////////////////////////////////////
  // SPIM Controller <=> CMD Memory //
  ////////////////////////////////////
  logic        ctrl_cmd_mem_ready;
  logic        cmd_mem_ctrl_valid;
  logic [31:0] cmd_mem_ctrl_rdata;


  //////////////////////////////////
  // SPIM Controller => SPIM TXRX //
  //////////////////////////////////
  logic        ctrl_txrx_cfg_cpol;
  logic        ctrl_txrx_cfg_cpha;

  logic        ctrl_txrx_tx_start;
  logic [15:0] ctrl_txrx_tx_size;
  logic [4:0]  ctrl_txrx_tx_bitsword;
  logic [1:0]  ctrl_txrx_tx_wordtransf;
  logic        ctrl_txrx_tx_lsbfirst;
  logic        ctrl_txrx_tx_qpi;
  logic [31:0] ctrl_txrx_tx_data;
  logic        ctrl_txrx_tx_valid;

  logic        ctrl_txrx_rx_start;
  logic [15:0] ctrl_txrx_rx_size;
  logic [4:0]  ctrl_txrx_rx_bitsword;
  logic [1:0]  ctrl_txrx_rx_wordtransf;
  logic        ctrl_txrx_rx_lsbfirst;
  logic        ctrl_txrx_rx_qpi;
  logic        ctrl_txrx_rx_ready;

  //////////////////////////////////
  // SPIM TXRX => SPIM Controller //
  //////////////////////////////////

  logic        txrx_ctrl_tx_ready;
  logic        txrx_ctrl_tx_done;

  logic [31:0] txrx_ctrl_rx_data;
  logic        txrx_ctrl_rx_valid;
  logic        txrx_ctrl_rx_done;

  //////////////////////////////////
  // RX Synchronization Registers //
  //////////////////////////////////
  logic [31:0] spi_rx_data_d, spi_rx_data_q;
  logic        spi_rx_data_valid_d, spi_rx_data_valid_q;


  
  ////////////////////////////////////////////////////////////////////////
  //  _____           _              _   _       _   _                  //
  // |_   _|         | |            | | (_)     | | (_)                 //
  //   | |  _ __  ___| |_ __ _ _ __ | |_ _  __ _| |_ _  ___  _ __  ___  //
  //   | | | '_ \/ __| __/ _` | '_ \| __| |/ _` | __| |/ _ \| '_ \/ __| //
  //  _| |_| | | \__ \ || (_| | | | | |_| | (_| | |_| | (_) | | | \__ \ //
  // |_____|_| |_|___/\__\__,_|_| |_|\__|_|\__,_|\__|_|\___/|_| |_|___/ //
  ////////////////////////////////////////////////////////////////////////

  //--------------------- Clock Generator ---------------------
  udma_clkgen u_clockgen
    (
     .clk_i,
     .rstn_i(rst_ni),
     .dft_test_mode_i,
     .dft_cg_enable_i,
     .clock_enable_i (cfgif_clkdiv_en),
     .clk_div_data_i (ctrl_clkdiv_data),
     .clk_div_valid_i (ctrl_clkdiv_valid),
     .clk_div_ack_o (clkdiv_ctrl_ack),
     .clk_o (s_clk_spi)
     );

  //----------------------- SPI Modules -----------------------
    wakeupspi_spim_ctrl #(
        .REPLAY_BUFFER_DEPTH(REPLAY_BUFFER_DEPTH)
    ) u_spictrl (
        .clk_i(s_clk_spi),
        .rstn_i(rst_ni),

        .eot_o(cs_clear_evt_o),

        .event_i(cfgif_ctrl_trigger_evt),

        .status_o(ctrl_cfgif_status),

        .cfg_cpol_o(ctrl_txrx_cfg_cpol),
        .cfg_cpha_o(ctrl_txrx_cfg_cpha),

        .cfg_clkdiv_data_o(ctrl_clkdiv_data),
        .cfg_clkdiv_valid_o(ctrl_clkdiv_valid),
        .cfg_clkdiv_ack_i(clkdiv_ctrl_ack),

        .tx_start_o(ctrl_txrx_tx_start),
        .tx_size_o(ctrl_txrx_tx_size),
        .tx_qpi_o(ctrl_txrx_tx_qpi),
        .tx_bitsword_o(ctrl_txrx_tx_bitsword),
        .tx_wordtransf_o(ctrl_txrx_tx_wordtransf),
        .tx_lsbfirst_o(ctrl_txrx_tx_lsbfirst),
        .tx_done_i(txrx_ctrl_tx_done),
        .tx_data_o(ctrl_txrx_tx_data),
        .tx_data_valid_o(ctrl_txrx_tx_valid),
        .tx_data_ready_i(txrx_ctrl_tx_ready),

        .rx_start_o(ctrl_txrx_rx_start),
        .rx_size_o(ctrl_txrx_rx_size),
        .rx_bitsword_o(ctrl_txrx_rx_bitsword),
        .rx_wordtransf_o(ctrl_txrx_rx_wordtransf),
        .rx_lsbfirst_o(ctrl_txrx_rx_lsbfirst),
        .rx_qpi_o(ctrl_txrx_rx_qpi),
        .rx_done_i(txrx_ctrl_rx_done),
        .rx_data_i(txrx_ctrl_rx_data),
        .rx_data_valid_i(txrx_ctrl_rx_valid),
        .rx_data_ready_o(ctrl_txrx_rx_ready),

        .wakeupspi_cmd_i(cmd_mem_ctrl_rdata),
        .wakeupspi_cmd_valid_i(cmd_mem_ctrl_valid),
        .wakeupspi_cmd_ready_o(ctrl_cmd_mem_ready),
        .wakeupspi_rx_data_o(ctrl_rx_data),
        .wakeupspi_rx_data_valid_o(ctrl_rx_valid),
        .wakeupspi_rx_data_ready_i(cfgif_ctrl_rx_ready),

        .spi_csn0_o(spi_csn0_o),
        .spi_csn1_o(spi_csn1_o),
        .spi_csn2_o(spi_csn2_o),
        .spi_csn3_o(spi_csn3_o)
    );

  wakeupspi_spim_txrx u_txrx
    (
     .clk_i(s_clk_spi),
     .rstn_i(rst_ni),
     .cfg_cpol_i(ctrl_txrx_cfg_cpol),
     .cfg_cpha_i(ctrl_txrx_cfg_cpha),

     .tx_start_i(ctrl_txrx_tx_start),
     .tx_size_i(ctrl_txrx_tx_size),
     .tx_bitsword_i(ctrl_txrx_tx_bitsword),
     .tx_wordtransf_i(ctrl_txrx_tx_wordtransf),
     .tx_lsbfirst_i(ctrl_txrx_tx_lsbfirst),
     .tx_qpi_i(ctrl_txrx_tx_qpi),
     .tx_done_o(txrx_ctrl_tx_done),
     .tx_data_i(ctrl_txrx_tx_data),
     .tx_data_valid_i(ctrl_txrx_tx_valid),
     .tx_data_ready_o(txrx_ctrl_tx_ready),

     .rx_start_i(ctrl_txrx_rx_start),
     .rx_size_i(ctrl_txrx_rx_size),
     .rx_bitsword_i(ctrl_txrx_rx_bitsword),
     .rx_wordtransf_i(ctrl_txrx_rx_wordtransf),
     .rx_lsbfirst_i(ctrl_txrx_rx_lsbfirst),
     .rx_qpi_i(ctrl_txrx_rx_qpi),
     .rx_done_o(txrx_ctrl_rx_done),
     .rx_data_o(txrx_ctrl_rx_data),
     .rx_data_valid_o(txrx_ctrl_rx_valid),
     .rx_data_ready_i(ctrl_txrx_rx_ready),

     .spi_clk_o(spi_clk_o),
     .spi_oen0_o(spi_oen0_o),
     .spi_oen1_o(spi_oen1_o),
     .spi_oen2_o(spi_oen2_o),
     .spi_oen3_o(spi_oen3_o),
     .spi_sdo0_o(spi_sdo0_o),
     .spi_sdo1_o(spi_sdo1_o),
     .spi_sdo2_o(spi_sdo2_o),
     .spi_sdo3_o(spi_sdo3_o),
     .spi_sdi0_i(spi_sdi0_i),
     .spi_sdi1_i(spi_sdi1_i),
     .spi_sdi2_i(spi_sdi2_i),
     .spi_sdi3_i(spi_sdi3_i)
    );


  ///////////////////////////////////////////////////////////////////////
  //   _____             __ _                       _   _              //
  //  / ____|           / _(_)                     | | (_)             //
  // | |     ___  _ __ | |_ _  __ _ _   _ _ __ __ _| |_ _  ___  _ __   //
  // | |    / _ \| '_ \|  _| |/ _` | | | | '__/ _` | __| |/ _ \| '_ \  //
  // | |___| (_) | | | | | | | (_| | |_| | | | (_| | |_| | (_) | | | | //
  //  \_____\___/|_| |_|_| |_|\__, |\__,_|_|  \__,_|\__|_|\___/|_| |_| //
  //                           __/ |                                   //
  //                          |___/                                    //
  //  _____       _             __                                     //
  // |_   _|     | |           / _|                                    //
  //   | |  _ __ | |_ ___ _ __| |_ __ _  ___ ___                       //
  //   | | | '_ \| __/ _ \ '__|  _/ _` |/ __/ _ \                      //
  //  _| |_| | | | ||  __/ |  | || (_| | (_|  __/                      //
  // |_____|_| |_|\__\___|_|  |_| \__,_|\___\___|                      //
  ///////////////////////////////////////////////////////////////////////

  logic [31:0] cfg_rdata_d, cfg_rdata_q;
  logic        cfg_rvalid_d, cfg_rvalid_q;

  logic [CMD_MEM_ADDR_WIDTH-1:0] cmd_mem_addr;
  logic                          cmd_mem_we;
  logic                          cmd_mem_addr_cntr_en;
  logic                          cmd_mem_addr_cntr_rst;
  logic [CMD_MEM_ADDR_WIDTH-1:0] cmd_mem_addr_cntr_d, cmd_mem_addr_cntr_q;

  logic [1:0]                     cfg_reg_spi_en_d, cfg_reg_spi_en_q;
  logic [CMD_MEM_ADDR_WIDTH-1:0]  cfg_reg_size_d, cfg_reg_size_q; //Contains the
                                                                 //size of the SPI uCode program. The counter
                                                                 //will reset when this value is hit


  //--------------------- Interface Logic ---------------------
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      cfg_rdata_q  <= '0;
      cfg_rvalid_q <= 1'b0;
    end else begin
      cfg_rdata_q  <= cfg_rdata_d;
      cfg_rvalid_q <= cfg_rvalid_d;
    end
  end

  always_comb begin
    cfg_gnt_o              = 1'b0;
    cfg_rdata_d            = cfg_rdata_q;
    cfg_rvalid_d           = 1'b0;
    cmd_mem_we             = 1'b0;
    cmd_mem_ctrl_valid     = 1'b0;
    cfg_reg_size_d         = cfg_reg_size_q;
    cfg_reg_spi_en_d       = cfg_reg_spi_en_q;
    cmd_mem_addr           = cmd_mem_addr_cntr_q;
    cmd_mem_addr_cntr_en   = ctrl_cmd_mem_ready;
    cmd_mem_addr_cntr_rst  = 1'b1;
    cmd_mem_ctrl_valid     = 1'b1;
    cfgif_ctrl_trigger_evt = 1'b0;

    if (cfg_req_i) begin
      if (cfg_addr_i[11:8] != 4'h0) begin
        case (cfg_addr_i[11:0])
          SPIM_REG_STATUS: begin
            cfg_gnt_o   = 1'b1;
            cfg_rdata_d = ctrl_cfgif_status;
            cfg_rvalid_d = 1'b1;
          end

          SPIM_REG_PROG_SIZE: begin
            if (cfg_we_i) begin
              cfg_gnt_o      = 1'b1;
              cfg_reg_size_d = cfg_wdata_i[CMD_MEM_ADDR_WIDTH-1:0];
            end else begin
              cfg_gnt_o   = 1'b1;
              cfg_rdata_d = cfg_reg_size_q;
              cfg_rvalid_d = 1'b1;
            end
          end

          SPIM_REG_ENABLE: begin
            if (cfg_we_i) begin
              cfg_gnt_o             = 1'b1;
              cfg_reg_spi_en_d      = cfg_wdata_i[1:0];
              cmd_mem_addr_cntr_rst = 1'b1;  //All write access cause the address counter to reset
            end else begin
              cfg_gnt_o    = 1'b1;
              cfg_rdata_d  = cfg_reg_spi_en_q;
              cfg_rvalid_d = 1'b1;
            end
          end // case: SPIM_REG_ENABLE

          SPIM_REG_RX_DATA: begin //Read-only reg
            cfg_gnt_o    = 1'b1;
            cfg_rdata_d  = spi_rx_data_q;
            cfg_rvalid_d = 1'b1;
          end

          SPIM_REG_CLR_INTRPT: begin
            if (cfg_we_i) begin
              cfg_gnt_o = 1'b1;
              cfgif_ctrl_trigger_evt = 1'b1;
            end else begin
              //Write-only register
              cfg_gnt_o    = 1'b1;
              cfg_rdata_d  = 32'hdeadda7a;
              cfg_rvalid_d = 1'b1;
            end
          end

          default: begin
            if (cfg_we_i) begin
              cfg_gnt_o = 1'b1; //Ignore the write request to the illegal
                                //address. Just grant the request.
            end else begin
              cfg_gnt_o   = 1'b1;
              cfg_rdata_d = 32'hdeadda7a;
              cfg_rvalid_d = 1'b1;
            end
          end
        endcase
      end else begin // if (cfg_addr_i[15:12] != 4'h0)
        //Command Memory access
        cfg_gnt_o            = 1'b1;
        cmd_mem_addr         = cfg_addr_i[CMD_MEM_ADDR_WIDTH+1:2];
        cmd_mem_addr_cntr_en = 1'b0;
        if (cfg_we_i) begin
          cmd_mem_we           = cfg_we_i;
        end else begin
          cfg_rvalid_d = 1'b1;
          cfg_rdata_d = cmd_mem_ctrl_rdata;
        end
      end // else: !if(cfg_addr_i[7])
    end // if (cfg_req_i)
  end // always_comb

  assign cfg_rdata_o     = cfg_rdata_q;
  assign cfg_rvalid_o    = cfg_rvalid_q;

  //------------------- SPI Enable Register -------------------
  assign cfgif_clkdiv_en = cfg_reg_spi_en_q[0];
  //If cfg_reg_spi_en_q[1] is high the ready signal from the accelerator is
  //bypassed and the valid signal to the accelerator stays deasserted. This
  //allows to manually read from SPI sensors with the configuration interface
  //withouth interference from the accelerator.
  assign cfgif_ctrl_rx_ready = cfg_reg_spi_en_q[1] | data_rx_ready_i;

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      cfg_reg_spi_en_q <= '0;
    end else begin
      cfg_reg_spi_en_q <= cfg_reg_spi_en_d;
    end
  end

  //-------------------- Prog Size Register --------------------
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      cfg_reg_size_q <= '0;
    end else begin
      cfg_reg_size_q <= cfg_reg_size_d;
    end
  end

  //--------------------- Address Counter ---------------------
  always_comb begin
     if (cmd_mem_addr_cntr_en)begin
       if (cmd_mem_addr_cntr_q == cfg_reg_size_q-1) begin
         cmd_mem_addr_cntr_d = '0;
       end else begin
         cmd_mem_addr_cntr_d = cmd_mem_addr_cntr_q+1;
       end
    end else begin
      cmd_mem_addr_cntr_d = cmd_mem_addr_cntr_q;
    end
  end

  always_ff @(posedge s_clk_spi, negedge rst_ni) begin
    if (!rst_ni) begin
      cmd_mem_addr_cntr_q <= '0;
    end else begin
      cmd_mem_addr_cntr_q <= cmd_mem_addr_cntr_d;
    end
  end

  //------------------------- Command Memory -------------------------
  scm_1rw #(.WORD_WIDTH(32), .ROW_CNT(CMD_MEM_SIZE)) i_cmd_memory
  (
   .clk_i,
   .rst_ni,
   .we_i(cmd_mem_we),
   .addr_i(cmd_mem_addr),
   .data_i(cfg_wdata_i),
   .data_o(cmd_mem_ctrl_rdata)
   );

  //--------------------- RX Synchronizer ---------------------
  //Latch the output of the txrx module with it's s_clk_spi
  //Antonio's SPI module does not support RX stalling at the moment so we do not
  //propagate the spi_rx_data_ready to the txrx module.
  assign spi_rx_data_d = ctrl_rx_valid ? ctrl_rx_data : spi_rx_data_q;
  assign spi_rx_data_valid_d = ctrl_rx_valid;

  typedef enum logic[1:0] {Invalid, WaitAck, Acknowledged} RxSyncState_e;
  RxSyncState_e rx_sync_state_d, rx_sync_state_q;

  always_comb begin
    data_rx_valid_o = 1'b0;
    rx_sync_state_d = rx_sync_state_q;
    if (!cfg_reg_spi_en_q[1]) begin
      case (rx_sync_state_q)
        Invalid: begin
          if (spi_rx_data_valid_q) begin
            rx_sync_state_d = WaitAck;
          end
        end

        WaitAck: begin
          data_rx_valid_o = 1'b1;
          if (data_rx_ready_i) begin
            rx_sync_state_d = Acknowledged;
          end
        end

        Acknowledged: begin
          data_rx_valid_o = 1'b0;
          if (spi_rx_data_valid_q == 1'b0) begin
            rx_sync_state_d = Invalid;
          end
        end

        default: begin
          rx_sync_state_d = Invalid;
        end
      endcase
    end
  end // always_comb

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      rx_sync_state_q <= Invalid;
    end else begin
      rx_sync_state_q <= rx_sync_state_d;
    end
  end

  always_ff @(posedge s_clk_spi, negedge rst_ni) begin
    if (!rst_ni) begin
      spi_rx_data_q       <= '0;
      spi_rx_data_valid_q <= 1'b0;
    end else begin
      spi_rx_data_q       <= spi_rx_data_d;
      spi_rx_data_valid_q <= spi_rx_data_valid_d;
    end
  end



  //-------------------- Output Assignments --------------------
  assign data_rx_o       = spi_rx_data_q;

endmodule : spi_top

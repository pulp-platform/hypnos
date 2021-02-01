//-------------------------------------------------------------------------------
// Title : HD Accelerator Wake-up Circuit Wrapper
// -----------------------------------------------------------------------------
// File : hd_accelerator_vega_wrap.sv Author : Manuel Eggimann
// <meggimann@iis.ee.ethz.ch> Created : 28.02.2019
// -----------------------------------------------------------------------------
// Description : This is a wrapper module for the hd accelerator for the
// integration as an autonomous wake up circuit. It instantiates the accelerator
// itself, an SPI master module to receive data from external ADCs as well as
// the analog interface module to communicate with the rest of the chip with a
// four phase handshaking protocol.
//-----------------------------------------------------------------------------
// SPDX-License-Identifier: SHL-0.51
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//-----------------------------------------------------------------------------

module hypnos
  import pkg_common::*;
  (
   input logic         refclk_i,
   input logic         rst_ni,
   input logic         dft_test_mode_i,
   input logic         dft_cg_enable_i,

   //External SoC Interface (asynchronous)
   output logic        wake_up_o, //Wakeup signal
   input logic         CFGREQ,
   input logic [31:0]  CFGD,
   input logic [15:0]  CFGAD,
   input logic         CFGWEB, // Active-low write enable
   output logic [31:0] CFGQ,
   output logic        CFGACK,

   //IO Pads
   output logic [11:0] io_DATA_o,
   input logic [11:0]  io_Y_i,
   output logic [11:0] io_RXEN_o,
   output logic [1:0]  io_DRV0_o,
   output logic [1:0]  io_DRV1_o,
   output logic [1:0]  io_DRV2_o,
   output logic [1:0]  io_DRV3_o,
   output logic [1:0]  io_DRV4_o,
   output logic [1:0]  io_DRV5_o,
   output logic [1:0]  io_DRV6_o,
   output logic [1:0]  io_DRV7_o,
   output logic [1:0]  io_DRV8_o,
   output logic [1:0]  io_DRV9_o,
   output logic [1:0]  io_DRV10_o,
   output logic [1:0]  io_DRV11_o,
   output logic [11:0] io_TRIEN_o,
   output logic [11:0] io_PUEN_o,
   output logic [11:0] io_PDEN_o
   );


  /////////////////////////////////////////////////////////////////////////////////
  //  _____       _                        _    _____ _                   _      //
  // |_   _|     | |                      | |  / ____(_)                 | |     //
  //   | |  _ __ | |_ ___ _ __ _ __   __ _| | | (___  _  __ _ _ __   __ _| |___  //
  //   | | | '_ \| __/ _ \ '__| '_ \ / _` | |  \___ \| |/ _` | '_ \ / _` | / __| //
  //  _| |_| | | | ||  __/ |  | | | | (_| | |  ____) | | (_| | | | | (_| | \__ \ //
  // |_____|_| |_|\__\___|_|  |_| |_|\__,_|_| |_____/|_|\__, |_| |_|\__,_|_|___/ //
  //                                                     __/ |                   //
  //                                                    |___/                    //
  /////////////////////////////////////////////////////////////////////////////////

  ////////////////////
  // Global Signals //
  ////////////////////
  logic                     sys_clk;    //Clock used for the accelerator
  logic                     int_clk;    //Clock generate by the FLL
  logic                     ext_clk;    //External clock supplied by io_pad[0]
  logic                     bypass_clk; //Selects which clock is used for sys_clk
  logic                     spi_clk_o;
  logic                     spi_csn0_o;
  logic                     spi_csn1_o;
  logic                     spi_csn2_o;
  logic                     spi_csn3_o;
  logic                     spi_oen0_o;
  logic                     spi_oen1_o;
  logic                     spi_oen2_o;
  logic                     spi_oen3_o;
  logic                     spi_sdo0_o;
  logic                     spi_sdo1_o;
  logic                     spi_sdo2_o;
  logic                     spi_sdo3_o;
  logic                     spi_sdi0_i;
  logic                     spi_sdi1_i;
  logic                     spi_sdi2_i;
  logic                     spi_sdi3_i;

  ///////////////////////////////////
  // config interface => io config //
  ///////////////////////////////////
  logic        cfgi_iocfg_cfg_req;
  logic        cfgi_iocfg_cfg_we;
  logic [15:0] cfgi_iocfg_cfg_addr;
  logic [31:0] cfgi_iocfg_cfg_wdata;

  ///////////////////////////////////
  // io config => config interface //
  ///////////////////////////////////
  logic        iocfg_cfgi_cfg_gnt;
  logic [31:0] iocfg_cfgi_cfg_rdata;
  logic        iocfg_cfgi_cfg_rvalid;

  /////////////////////////////////////////
  // config interface => hd_accelerator //
  /////////////////////////////////////////
  logic        cfgi_hdacc_cfg_req;
  logic        cfgi_hdacc_cfg_wen;
  logic [15:0] cfgi_hdacc_cfg_addr;
  logic [31:0] cfgi_hdacc_cfg_wdata;

  /////////////////////////////////////////
  // hd_accelerator => config interface //
  /////////////////////////////////////////
  logic        hdacc_cfgi_cfg_gnt;
  logic [31:0] hdacc_cfgi_cfg_rdata;
  logic        hdacc_cfgi_cfg_rvalid;

  ////////////////////////////////////
  // config interface => SPI master //
  ////////////////////////////////////
  logic        cfgi_spim_cfg_req;
  logic        cfgi_spim_cfg_we;
  logic [15:0] cfgi_spim_cfg_addr;
  logic [31:0] cfgi_spim_cfg_wdata;

  ////////////////////////////////////
  // SPI Master => config interface //
  ////////////////////////////////////
  logic        spim_cfgi_cfg_gnt;
  logic [31:0] spim_cfgi_cfg_rdata;
  logic        spim_cfgi_cfg_rvalid;

  //////////////////////////////////////
  // config interface => Preprocesser //
  //////////////////////////////////////
  logic        cfgi_preproc_cfg_req;
  logic        cfgi_preproc_cfg_we;
  logic [15:0] cfgi_preproc_cfg_addr;
  logic [31:0] cfgi_preproc_cfg_wdata;

  //////////////////////////////////////
  // Preprocessor => config interface //
  //////////////////////////////////////
  logic        preproc_cfgi_cfg_gnt;
  logic [31:0] preproc_cfgi_cfg_rdata;
  logic        preproc_cfgi_cfg_rvalid;

  ////////////////////////////////
  // SPI Master => Preprocessor //
  ////////////////////////////////
  logic [31:0] spim_preproc_data_rx;
  logic        spim_preproc_data_valid;

  ////////////////////////////////
  // Preprocessor => SPI Master //
  ////////////////////////////////
  logic        preproc_spim_data_ready;

  ////////////////////////////////////
  // Preprocessor => hd_accelerator //
  ////////////////////////////////////
  logic [PREPROC_DATA_WIDTH-1:0] preproc_hdacc_data;
  logic                          preproc_hdacc_data_valid;
  logic                          hdacc_preproc_switch_channel;
  logic                          hdacc_preproc_ack_sample;

  ////////////////////////////////////
  // hd_accelerator => Preprocessor //
  ////////////////////////////////////


  ///////////////////////////////////////////////////////////
  //  _____        _____     _____             __ _        //
  // |  __ \ /\   |  __ \   / ____|           / _(_)       //
  // | |__) /  \  | |  | | | |     ___  _ __ | |_ _  __ _  //
  // |  ___/ /\ \ | |  | | | |    / _ \| '_ \|  _| |/ _` | //
  // | |  / ____ \| |__| | | |___| (_) | | | | | | | (_| | //
  // |_| /_/    \_\_____/   \_____\___/|_| |_|_| |_|\__, | //
  //                                                 __/ | //
  //                                                |___/  //
  ///////////////////////////////////////////////////////////

  //   |---------------+---------------------------+----------------------+--------------------------------------------------------------------------------------|
  //   | External Name | Internal Name             | IO Pads Configurable | Description                                                                          |
  //   |---------------+---------------------------+----------------------+--------------------------------------------------------------------------------------|
  //   | io[0]         | ext_clk                   | No                   | External Clock that is used in the accelerator if bypas_clk is asserted.             |
  //   | io[1]         | bypass_clk                | No                   | Enables the clock bypassing and uses the external clock instead of the internal one. |
  //   | io[2]         | spi_clk_o                 | yes                  | SPI Master Clock                                                                     |
  //   | io[3]         | MOSI/ spi_sdi0_i/spi_sdo0 | yes                  | SPI Data line                                                                        |
  //   | io[4]         | MISO/ spi_sdi1_i/spi_sdo1 | yes                  | SPI Data line                                                                        |
  //   | io[5]         | spi_sdi2_i/spi_sdo2       | yes                  | SPI Data line                                                                        |
  //   | io[6]         | spi_sdi3_i/spi_sdo3       | yes                  | SPI Data line                                                                        |
  //   | io[7]         | spi_csn0_o                | yes                  | SPI Chip Select                                                                      |
  //   | io[8]         | spi_csn1_o                | yes                  | SPI Chip Select                                                                      |
  //   | io[9]         | spi_csn2_o                | yes                  | SPI Chip Select                                                                      |
  //   | io[10]        | spi_csn3_o                | yes                  | SPI Chip Select                                                                      |
  //   | io[11]        | Unused                    | no                   | Not used in the design                                                               |
  //   |---------------+---------------------------+----------------------+--------------------------------------------------------------------------------------|



  //-------------------- Static Pad Config --------------------
  //  t_clk
  assign io_DATA_o[0]   = 1'b0;
  assign io_RXEN_o[0]   = 1'b1;
  assign io_TRIEN_o[0]  = 1'b1;
  assign io_DRV0_o      = '0;
  assign io_PDEN_o[0]   = 1'b0;
  assign io_PUEN_o[0]   = 1'b0;
  assign ext_clk        = io_Y_i[0];

  //bypass_clk
  assign io_DATA_o[1]   = 1'b0;
  assign io_RXEN_o[1]   = 1'b1;
  assign io_TRIEN_o[1]  = 1'b1;
  assign io_DRV1_o      = '0;
  assign io_PDEN_o[1]   = 1'b0;
  assign io_PUEN_o[1]   = 1'b0;
  assign bypass_clk     = io_Y_i[1];

  //Not used pad
  assign io_DATA_o[11]  = 1'b0;
  assign io_RXEN_o[11]  = 1'b0;
  assign io_TRIEN_o[11] = 1'b1;
  assign io_DRV11_o     = '0;
  assign io_PDEN_o[11]  = 1'b0;
  assign io_PUEN_o[11]  = 1'b0;


  //----------------- Pad Config Registers -----------------
  typedef struct packed {
    logic        RXEN;
    logic        TRIEN;
    logic [1:0]  DRV;
    logic        PUEN;
    logic        PDEN;
  } pad_config_t;

  pad_config_t   pad_config_d[9], pad_config_q[9];

  always_comb begin
    pad_config_d          = pad_config_q;
    iocfg_cfgi_cfg_gnt    = 1'b0;
    iocfg_cfgi_cfg_rdata  = 'X;
    iocfg_cfgi_cfg_rvalid = 1'b0;
    if (cfgi_iocfg_cfg_req) begin
      if (cfgi_iocfg_cfg_addr[5:2]<10) begin
        if (cfgi_iocfg_cfg_we) begin
          //Write request
          iocfg_cfgi_cfg_gnt = 1'b1;
          pad_config_d[cfgi_iocfg_cfg_addr[5:2]] = cfgi_iocfg_cfg_wdata[$bits(pad_config_t)-1:0];
        end else begin
          //Read request
          iocfg_cfgi_cfg_gnt    = 1'b1;
          iocfg_cfgi_cfg_rdata  = pad_config_q[cfgi_iocfg_cfg_addr[5:2]];
          iocfg_cfgi_cfg_rvalid = 1'b1;
        end
      end else begin
        //Illegal address
        if (cfgi_iocfg_cfg_we) begin
          iocfg_cfgi_cfg_gnt = 1'b1;
        end else begin
          iocfg_cfgi_cfg_gnt    = 1'b1;
          iocfg_cfgi_cfg_rvalid = 1'b1;
          iocfg_cfgi_cfg_rdata  = 32'hdeadda7a;
        end
      end
    end
  end // always_comb

  for (genvar i = 0; i < 9; i++) begin
    always_ff @(posedge sys_clk, negedge rst_ni) begin
      if (!rst_ni) begin
        pad_config_q[i].RXEN  <= 1'b0;
        pad_config_q[i].TRIEN <= 1'b1;
        pad_config_q[i].DRV   <= '0;
        pad_config_q[i].PUEN  <= 1'b0;
        pad_config_q[i].PDEN  <= 1'b0;
      end else begin
        pad_config_q[i] <= pad_config_d[i];
      end
    end
  end


  //--------------- Config of configurable pads ---------------
  assign io_DATA_o[2]  = spi_clk_o;
  assign io_DATA_o[3]  = spi_sdo0_o;
  assign io_DATA_o[4]  = spi_sdo1_o;
  assign io_DATA_o[5]  = spi_sdo2_o;
  assign io_DATA_o[6]  = spi_sdo3_o;
  assign io_DATA_o[7]  = spi_csn0_o;
  assign io_DATA_o[8]  = spi_csn1_o;
  assign io_DATA_o[9]  = spi_csn2_o;
  assign io_DATA_o[10] = spi_csn3_o;

  assign spi_sdi0_i = io_Y_i[3];
  assign spi_sdi1_i = io_Y_i[4];
  assign spi_sdi2_i = io_Y_i[5];
  assign spi_sdi3_i = io_Y_i[6];


  //Assignments for spi_sdi/spi_sdo signals. Output enable for automaic SPI/QSPI
  //switching of the SPIM module only works if the corresponding pad
  //configuration register have RXEN=1 and TRIEN=0 (LOOPBACK settings)

  //Hardcoded assignments for io_DRV_o signals (fixes synthesis issues with 2D
  //arrays)
  //SPI clock
  assign io_RXEN_o[2]  = pad_config_q[0].RXEN;
  assign io_TRIEN_o[2] = pad_config_q[0].TRIEN;
  assign io_DRV2_o   = pad_config_q[0].DRV;
  assign io_PDEN_o[2]  = pad_config_q[0].PDEN;
  assign io_PUEN_o[2] = pad_config_q[0].PUEN;

  //MOSI/SDIO0
  assign io_RXEN_o[3]  = spi_oen0_o & pad_config_q[1].RXEN;
  assign io_TRIEN_o[3] = spi_oen0_o & !pad_config_q[1].TRIEN;
  assign io_DRV3_o   = pad_config_q[1].DRV;
  assign io_PDEN_o[3]  = pad_config_q[1].PDEN;
  assign io_PUEN_o[3]  = pad_config_q[1].PUEN;

  //MISO/SDIO1
  assign io_RXEN_o[4]  = spi_oen1_o & pad_config_q[2].RXEN;
  assign io_TRIEN_o[4] = spi_oen1_o & !pad_config_q[2].TRIEN;
  assign io_DRV4_o   = pad_config_q[2].DRV;
  assign io_PDEN_o[4]  = pad_config_q[2].PDEN;
  assign io_PUEN_o[4]  = pad_config_q[2].PUEN;

  //SDIO2
  assign io_RXEN_o[5]  = spi_oen2_o & pad_config_q[3].RXEN;
  assign io_TRIEN_o[5] = spi_oen2_o & !pad_config_q[3].TRIEN;
  assign io_DRV5_o   = pad_config_q[3].DRV;
  assign io_PDEN_o[5]  = pad_config_q[3].PDEN;
  assign io_PUEN_o[5]  = pad_config_q[3].PUEN;

  //SDIO3
  assign io_RXEN_o[6]  = spi_oen3_o & pad_config_q[4].RXEN;
  assign io_TRIEN_o[6] = spi_oen3_o & !pad_config_q[4].TRIEN;
  assign io_DRV6_o   = pad_config_q[4].DRV;
  assign io_PDEN_o[6]  = pad_config_q[4].PDEN;
  assign io_PUEN_o[6]  = pad_config_q[4].PUEN;


  //Chip Selects
  for (genvar i = 5; i < 9; i++) begin
    assign io_RXEN_o[i+2]  = pad_config_q[i].RXEN;
    assign io_TRIEN_o[i+2] = pad_config_q[i].TRIEN;
    assign io_PDEN_o[i+2]  = pad_config_q[i].PDEN;
    assign io_PUEN_o[i+2]  = pad_config_q[i].PUEN;
  end
  assign io_DRV7_o = pad_config_q[5].DRV;
  assign io_DRV8_o = pad_config_q[6].DRV;
  assign io_DRV9_o = pad_config_q[7].DRV;
  assign io_DRV10_o = pad_config_q[8].DRV;


  ////////////////////////////////////////////////////
  //   _____ _            _      __  __             //
  //  / ____| |          | |    |  \/  |            //
  // | |    | | ___   ___| | __ | \  / |_   ___  __ //
  // | |    | |/ _ \ / __| |/ / | |\/| | | | \ \/ / //
  // | |____| | (_) | (__|   <  | |  | | |_| |>  <  //
  //  \_____|_|\___/ \___|_|\_\ |_|  |_|\__,_/_/\_\ //
  ////////////////////////////////////////////////////

  assign int_clk = refclk_i; // TODO change once FLL is ready and instantiated

  pulp_clock_mux2 i_sys_clk_sel
    (.clk0_i(int_clk),
     .clk1_i(ext_clk),
     .clk_sel_i(bypass_clk),
     .clk_o(sys_clk));

  ////////////////////////////////////////////////////////////////////////
  //  _____           _              _   _       _   _                  //
  // |_   _|         | |            | | (_)     | | (_)                 //
  //   | |  _ __  ___| |_ __ _ _ __ | |_ _  __ _| |_ _  ___  _ __  ___  //
  //   | | | '_ \/ __| __/ _` | '_ \| __| |/ _` | __| |/ _ \| '_ \/ __| //
  //  _| |_| | | \__ \ || (_| | | | | |_| | (_| | |_| | (_) | | | \__ \ //
  // |_____|_| |_|___/\__\__,_|_| |_|\__|_|\__,_|\__|_|\___/|_| |_|___/ //
  ////////////////////////////////////////////////////////////////////////

  //------------------- Module instantiation -------------------
  spi_top
    #(
      .REPLAY_BUFFER_DEPTH(6),
      .CMD_MEM_SIZE(32)
      ) i_spim
    (
     .clk_i(sys_clk),
     .rst_ni,
     .dft_test_mode_i,
     .dft_cg_enable_i,

     .cs_clear_evt_o(),

     .cfg_req_i(cfgi_spim_cfg_req),
     .cfg_gnt_o(spim_cfgi_cfg_gnt),
     .cfg_we_i(cfgi_spim_cfg_we),
     .cfg_addr_i(cfgi_spim_cfg_addr[11:0]),
     .cfg_wdata_i(cfgi_spim_cfg_wdata),
     .cfg_rdata_o(spim_cfgi_cfg_rdata),
     .cfg_rvalid_o(spim_cfgi_cfg_rvalid),

     .data_rx_o(spim_preproc_data_rx),
     .data_rx_valid_o(spim_preproc_data_valid),
     .data_rx_ready_i(preproc_spim_data_ready),

     .spi_clk_o,
     .spi_csn0_o,
     .spi_csn1_o,
     .spi_csn2_o,
     .spi_csn3_o,
     .spi_oen0_o,
     .spi_oen1_o,
     .spi_oen2_o,
     .spi_oen3_o,
     .spi_sdo0_o,
     .spi_sdo1_o,
     .spi_sdo2_o,
     .spi_sdo3_o,
     .spi_sdi0_i,
     .spi_sdi1_i,
     .spi_sdi2_i,
     .spi_sdi3_i
     );

  hd_accelerator i_hd_accelerator
    (
     .clk_i(sys_clk),
     .dft_test_mode_i,
     .rst_ni,
     .host_intr_o(wake_up_o),
     .cfg_req_i(cfgi_hdacc_cfg_req),
     .cfg_gnt_o(hdacc_cfgi_cfg_gnt),
     .cfg_wen_i(cfgi_hdacc_cfg_wen),
     .cfg_addr_i(cfgi_hdacc_cfg_addr),
     .cfg_wdata_i(cfgi_hdacc_cfg_wdata),
     .cfg_rdata_o(hdacc_cfgi_cfg_rdata),
     .cfg_rvalid_o(hdacc_cfgi_cfg_rvalid),
     .idata_switch_channel_o(hdacc_preproc_switch_channel),
     .idata_ack_sample_o(hdacc_preproc_ack_sample),
     .idata_valid_i(preproc_hdacc_data_valid),
     .idata_i(preproc_hdacc_data)
     );

  preprocessor_top
    #(
      .NR_CHANNELS(PREPROC_NR_CHANNELS),
      .DATA_WIDTH(PREPROC_DATA_WIDTH),
      .ALPHA_WIDTH(PREPROC_ALPHA_WDITH),
      .LBP_CODESIZE(PREPROC_LBP_CODESIZE),
      .FIFO_DEPTH(PREPROC_FIFO_DEPTH),
      .SUBSAMPLING_WITH(PREPROC_SUBSAMPLING_WIDTH)
    ) i_preprocessor (
      .clk_i(sys_clk),
      .rst_ni,
      .testmode_i(dft_test_mode_i),

      .idata_i(spim_preproc_data_rx[PREPROC_DATA_WIDTH-1:0]),
      .idata_valid_i(spim_preproc_data_valid),
      .idata_ready_o(preproc_spim_data_ready),
      .odata_o(preproc_hdacc_data),
      .odata_valid_o(preproc_hdacc_data_valid),
      .odata_switch_channel_i(hdacc_preproc_switch_channel),
      .odata_ack_sample_i(hdacc_preproc_ack_sample),

      .cfg_req_i(cfgi_preproc_cfg_req),
      .cfg_gnt_o(preproc_cfgi_cfg_gnt),
      .cfg_we_i(cfgi_preproc_cfg_we),
      .cfg_addr_i(cfgi_preproc_cfg_addr[11:0]),
      .cfg_wdata_i(cfgi_preproc_cfg_wdata),
      .cfg_rdata_o(preproc_cfgi_cfg_rdata),
      .cfg_rvalid_o(preproc_cfgi_cfg_rvalid)
      );

  cfg_iface i_cfg_iface
    (
     .rst_ni,
     .CFGREQ,
     .CFGD,
     .CFGAD,
     .CFGWEB,
     .CFGQ,
     .CFGACK,
     .clk_i(sys_clk),
     .accl_cfg_req_o(cfgi_hdacc_cfg_req),
     .accl_cfg_gnt_i(hdacc_cfgi_cfg_gnt),
     .accl_cfg_wen_o(cfgi_hdacc_cfg_wen),
     .accl_cfg_addr_o(cfgi_hdacc_cfg_addr),
     .accl_cfg_wdata_o(cfgi_hdacc_cfg_wdata),
     .accl_cfg_rdata_i(hdacc_cfgi_cfg_rdata),
     .accl_cfg_rvalid_i(hdacc_cfgi_cfg_rvalid),

     .spim_cfg_req_o(cfgi_spim_cfg_req),
     .spim_cfg_gnt_i(spim_cfgi_cfg_gnt),
     .spim_cfg_we_o(cfgi_spim_cfg_we),
     .spim_cfg_addr_o(cfgi_spim_cfg_addr),
     .spim_cfg_wdata_o(cfgi_spim_cfg_wdata),
     .spim_cfg_rdata_i(spim_cfgi_cfg_rdata),
     .spim_cfg_rvalid_i(spim_cfgi_cfg_rvalid),

     .io_cfg_req_o(cfgi_iocfg_cfg_req),
     .io_cfg_gnt_i(iocfg_cfgi_cfg_gnt),
     .io_cfg_we_o(cfgi_iocfg_cfg_we),
     .io_cfg_addr_o(cfgi_iocfg_cfg_addr),
     .io_cfg_wdata_o(cfgi_iocfg_cfg_wdata),
     .io_cfg_rdata_i(iocfg_cfgi_cfg_rdata),
     .io_cfg_rvalid_i(iocfg_cfgi_cfg_rvalid),

     .preproc_cfg_req_o(cfgi_preproc_cfg_req),
     .preproc_cfg_gnt_i(preproc_cfgi_cfg_gnt),
     .preproc_cfg_we_o(cfgi_preproc_cfg_we),
     .preproc_cfg_addr_o(cfgi_preproc_cfg_addr),
     .preproc_cfg_wdata_o(cfgi_preproc_cfg_wdata),
     .preproc_cfg_rdata_i(preproc_cfgi_cfg_rdata),
     .preproc_cfg_rvalid_i(preproc_cfgi_cfg_rvalid)
     );

endmodule : hypnos

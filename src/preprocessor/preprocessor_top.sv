//-----------------------------------------------------------------------------
// Title : Preprocessor
// -----------------------------------------------------------------------------
// File : preprocessor_top.sv Author : Manuel Eggimann
// <meggimann@iis.ee.ethz.ch> Created : 18.03.2019
// -----------------------------------------------------------------------------
// Description : Contains a number of configurable preprocessing stages. Each
// input channel has its own stage and the incomming samples are time
// multiplexed over the enabled channels.
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

module preprocessor_top
  import pkg_common::*;
  import pkg_memory_mapping::*;
  #(
    parameter NR_CHANNELS      = 8,  // 2 < = x < = 32
    parameter DATA_WIDTH       = 16, // <   =32
    parameter ALPHA_WIDTH      = 8,
    parameter LBP_CODESIZE     = 6,
    parameter FIFO_DEPTH       = 4,  // Output FIFO depth
    parameter SUBSAMPLING_WITH = 16  //The counter with of the subsampling
                                     //counter and config register
    )
  (
   input logic                   clk_i,
   input logic                   rst_ni,
   input logic                   testmode_i,

   //Datapath
   input logic [DATA_WIDTH-1:0]  idata_i,
   input logic                   idata_valid_i,
   output logic                  idata_ready_o,
   output logic [DATA_WIDTH-1:0] odata_o,
   output logic                  odata_valid_o,
   input logic                   odata_switch_channel_i,
   input logic                   odata_ack_sample_i,

   //Config Interface
   input logic                   cfg_req_i,
   output logic                  cfg_gnt_o,
   input logic                   cfg_we_i,
   input logic [11:0]            cfg_addr_i,
   input word_t                  cfg_wdata_i,
   output word_t                 cfg_rdata_o,
   output logic                  cfg_rvalid_o
   );

  typedef struct packed {
    logic                          channel_en;
    logic                          offset_removal_en;
    logic [ALPHA_WIDTH-1:0]        offset_removal_alpha;
    logic                          rms_en;
    logic [ALPHA_WIDTH-1:0]        rms_alpha;
    logic                          use_lbp;
    logic [$clog2(DATA_WIDTH)-1:0] output_shift_right;
    logic [$clog2(DATA_WIDTH)-1:0] input_shift_left;
  } channel_config_t;


  ///////////////////////////////////////////////////////////////
  //   _____                            _   _                  //
  //  / ____|                          | | (_)                 //
  // | |     ___  _ __  _ __   ___  ___| |_ _  ___  _ __  ___  //
  // | |    / _ \| '_ \| '_ \ / _ \/ __| __| |/ _ \| '_ \/ __| //
  // | |___| (_) | | | | | | |  __/ (__| |_| | (_) | | | \__ \ //
  //  \_____\___/|_| |_|_| |_|\___|\___|\__|_|\___/|_| |_|___/ //
  ///////////////////////////////////////////////////////////////

  //--------------------- Output FIFO => * ---------------------
  logic [NR_CHANNELS-1:0]         ofifo_full;
  logic [NR_CHANNELS-1:0]         ofifo_empty;

  //------------ Offset Removal Stage => RMS Stage ------------
  logic signed [DATA_WIDTH-1:0]   offremstage_rmsstage_data;

  //----------------- RMS Stage => Sub Sampler -----------------
  logic signed [DATA_WIDTH-1:0]   rmsstage_subsampl_data;

  //----------------- LBP Stage => Sub Sampler -----------------
  logic [LBP_CODESIZE-1:0]        lbp_subsampl_data [NR_CHANNELS];
  logic                           lbp_subsampl_valid [NR_CHANNELS];

  //---------------- Sub Sampler => Output FIFO ----------------
  logic                           subsampling_ofifo_push [NR_CHANNELS];
  logic [DATA_WIDTH-1:0]          subsampling_ofifo_data;

  //---------------- Output FIFO => Output Mux ----------------
  logic [DATA_WIDTH-1:0]          ofifo_outmux_data[NR_CHANNELS];

  //--------------------- Pipeline Control ---------------------
  logic [NR_CHANNELS-1:0]         active_channel; //One-hot encoded
                                                //channel that is currently active for input sampling
  logic [$clog2(NR_CHANNELS)-1:0] active_channel_idx;
  logic [NR_CHANNELS-1:0]         selected_channel; //One-hot encoded
                                                  //channel that is currently selected by the HD-Accelerator

  logic                           pipeline_enable;
  logic                           preprocessor_reset;
  logic [NR_CHANNELS-1:0]         enabled_channels;

  assign pipeline_enable = idata_valid_i & |active_channel & ~|(ofifo_full & active_channel);
  assign idata_ready_o   = pipeline_enable;

  //////////////////////////////////////////////////////////////////////////////////
  //   _____             __ _         _____       _             __                //
  //  / ____|           / _(_)       |_   _|     | |           / _|               //
  // | |     ___  _ __ | |_ _  __ _    | |  _ __ | |_ ___ _ __| |_ __ _  ___ ___  //
  // | |    / _ \| '_ \|  _| |/ _` |   | | | '_ \| __/ _ \ '__|  _/ _` |/ __/ _ \ //
  // | |___| (_) | | | | | | | (_| |  _| |_| | | | ||  __/ |  | || (_| | (_|  __/ //
  //  \_____\___/|_| |_|_| |_|\__, | |_____|_| |_|\__\___|_|  |_| \__,_|\___\___| //
  //                           __/ |                                              //
  //                          |___/                                               //
  //////////////////////////////////////////////////////////////////////////////////

  //--------------------- Config Registers ---------------------
  channel_config_t              channel_config_d[NR_CHANNELS], channel_config_q[NR_CHANNELS];
  logic signed [DATA_WIDTH-1:0] channel_pre_offset_d[NR_CHANNELS], channel_pre_offset_q[NR_CHANNELS];
  logic signed [DATA_WIDTH-1:0] channel_post_offset_d[NR_CHANNELS], channel_post_offset_q[NR_CHANNELS];
  logic [SUBSAMPLING_WITH-1:0]  cfg_reg_subsampling_d, cfg_reg_subsampling_q; // = subsampling_factor - 1
  word_t                        cfg_rdata_d, cfg_rdata_q;
  logic                         cfg_rvalid_d, cfg_rvalid_q;

  assign cfg_rdata_o = cfg_rdata_q;
  assign cfg_rvalid_o = cfg_rvalid_q;

  always_comb begin
    channel_config_d      = channel_config_q;
    cfg_reg_subsampling_d = cfg_reg_subsampling_q;
    channel_pre_offset_d  = channel_pre_offset_q;
    channel_post_offset_d = channel_post_offset_q;
    preprocessor_reset    = 1'b0;
    cfg_rdata_d           = cfg_rdata_q;
    cfg_rvalid_d          = 1'b0;
    cfg_gnt_o             = 1'b0;
    if (cfg_req_i) begin
      case (cfg_addr_i[11:0])
        PREPROC_REG_SUBSAMPLING: begin
          if (cfg_we_i) begin
            cfg_gnt_o             = 1'b1;
            cfg_reg_subsampling_d = cfg_wdata_i[SUBSAMPLING_WITH-1:0];
          end else begin
            cfg_gnt_o                         = 1'b1;
            cfg_rdata_d[SUBSAMPLING_WITH-1:0] = cfg_reg_subsampling_q;
            cfg_rvalid_d                      = 1'b1;
          end
        end

        //Resets the state of the preprocessor block without affecting the configuration registers
        PREPROC_REG_SOFT_RESET: begin
          if (cfg_we_i) begin
            cfg_gnt_o          = 1'b1;
            preprocessor_reset = 1'b1;
          end else begin
            //Always return with 0
            cfg_rdata_d  = '0;
            cfg_rvalid_d = 1'b1;
          end

        end
        default: begin
          if (cfg_addr_i[11:8] == 4'h0) begin
            //Channel config request
            if (cfg_addr_i[5:2]<NR_CHANNELS) begin
              if (cfg_we_i) begin
                cfg_gnt_o                         = 1'b1;
                channel_config_d[cfg_addr_i[5:2]] = cfg_wdata_i[$bits(channel_config_t)-1:0];
              end else begin
                cfg_gnt_o                                = 1'b1;
                cfg_rdata_d                              = '0;
                cfg_rdata_d[$bits(channel_config_t)-1:0] = channel_config_q[cfg_addr_i[5:2]];
                cfg_rvalid_d                             = 1'b1;
              end
            end else begin // if (cfg_addr_i[3:0]<NR_CHANNELS)
              //Illegal address
              if (cfg_we_i) begin
                cfg_gnt_o = 1'b1;
              end else begin
                cfg_rdata_d  = 32'hdeadda7a;
                cfg_rvalid_d = 1'b1;
              end
            end // else: !if(cfg_addr_i[5:2]<NR_CHANNELS)
          end else if (cfg_addr_i[11:8] == 4'h1) begin
            //Channel pre offset configuration
            if (cfg_addr_i[5:2]<NR_CHANNELS) begin
              if (cfg_we_i) begin
                cfg_gnt_o = 1'b1;
                channel_pre_offset_d[cfg_addr_i[5:2]] = cfg_wdata_i[DATA_WIDTH-1:0];
              end else begin
                cfg_gnt_o                   = 1'b1;
                cfg_rdata_d                 = '0;
                cfg_rdata_d[DATA_WIDTH-1:0] = channel_pre_offset_q[cfg_addr_i[5:2]];
                cfg_rvalid_d                = 1'b1;
              end
            end else begin // if (cfg_addr_i[3:0]<NR_CHANNELS)
              //Illegal address
              if (cfg_we_i) begin
                cfg_gnt_o = 1'b1;
              end else begin
                cfg_rdata_d  = 32'hdeadda7a;
                cfg_rvalid_d = 1'b1;
              end
            end // else: !if(cfg_addr_i[5:2]<NR_CHANNELS)
          end else if (cfg_addr_i[11:8] == 4'h2) begin
            //Channel post offset configuration
            if (cfg_addr_i[5:2]<NR_CHANNELS) begin
              if (cfg_we_i) begin
                cfg_gnt_o = 1'b1;
                channel_post_offset_d[cfg_addr_i[5:2]] = cfg_wdata_i[DATA_WIDTH-1:0];
              end else begin
                cfg_gnt_o                   = 1'b1;
                cfg_rdata_d                 = '0;
                cfg_rdata_d[DATA_WIDTH-1:0] = channel_post_offset_q[cfg_addr_i[5:2]];
                cfg_rvalid_d                = 1'b1;
              end
            end else begin // if (cfg_addr_i[3:0]<NR_CHANNELS)
              //Illegal address
              if (cfg_we_i) begin
                cfg_gnt_o = 1'b1;
              end else begin
                cfg_rdata_d  = 32'hdeadda7a;
                cfg_rvalid_d = 1'b1;
              end
            end // else: !if(cfg_addr_i[5:2]<NR_CHANNELS)

        end else begin
            //Illegal address
            if (cfg_we_i) begin
              cfg_gnt_o = 1'b1;
            end else begin
              cfg_rdata_d  = 32'hdeadda7a;
              cfg_rvalid_d = 1'b1;
            end
          end
        end
      endcase
    end
  end

  for (genvar i = 0; i < NR_CHANNELS; i++) begin :channel_config_regs
    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni) begin
        channel_config_q[i]      <= '0;
        channel_pre_offset_q[i]  <= '0;
        channel_post_offset_q[i] <= '0;
      end else begin
        channel_config_q[i]      <= channel_config_d[i];
        channel_pre_offset_q[i]  <= channel_pre_offset_d[i];
        channel_post_offset_q[i] <= channel_post_offset_d[i];
      end
    end
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      cfg_reg_subsampling_q <= '0;
      cfg_rdata_q           <= '0;
      cfg_rvalid_q          <= 1'b0;
    end else begin
      cfg_reg_subsampling_q <= cfg_reg_subsampling_d;
      cfg_rdata_q           <= cfg_rdata_d;
      cfg_rvalid_q          <= cfg_rvalid_d;
    end
  end


  /////////////////////////////////////////////////////////////////////////////////////
  //  _____                   _     __  __       _ _   _       _                     //
  // |_   _|                 | |   |  \/  |     | | | (_)     | |                    //
  //   | |  _ __  _ __  _   _| |_  | \  / |_   _| | |_ _ _ __ | | _____  _____ _ __  //
  //   | | | '_ \| '_ \| | | | __| | |\/| | | | | | __| | '_ \| |/ _ \ \/ / _ \ '__| //
  //  _| |_| | | | |_) | |_| | |_  | |  | | |_| | | |_| | |_) | |  __/>  <  __/ |    //
  // |_____|_| |_| .__/ \__,_|\__| |_|  |_|\__,_|_|\__|_| .__/|_|\___/_/\_\___|_|    //
  //             | |                                    | |                          //
  //             |_|                                    |_|                          //
  /////////////////////////////////////////////////////////////////////////////////////


  //One-hot encoding of active channel. e.g. 0b0100 -> channel with idx=2 is
  //active
  logic [NR_CHANNELS-1:0] input_mux_state_d, input_mux_state_q;
  logic                   is_last_enabled_channel;

  onehot_to_bin #(.ONEHOT_WIDTH(NR_CHANNELS)) i_onehot_to_bin
    (
     .onehot(active_channel),
     .bin(active_channel_idx)
     );

  always_comb begin
    for (int i = 0; i < NR_CHANNELS; i++) begin
      enabled_channels[i] = channel_config_q[i].channel_en;
    end
  end

  always_comb begin
    input_mux_state_d       = input_mux_state_q;
    active_channel          = '0;
    is_last_enabled_channel = 1'b0;

    for (int i = NR_CHANNELS-1; i >= 0; i--) begin
      if (input_mux_state_q[i]) begin
        active_channel    = '0;
        active_channel[i] = 1'b1;
      end
    end

    if (preprocessor_reset) begin
      input_mux_state_d          = enabled_channels;
    end else if (pipeline_enable) begin
      input_mux_state_d                        = active_channel ^ input_mux_state_q;
      if ((active_channel ^ input_mux_state_q) == '0) begin
        is_last_enabled_channel = 1'b1;
        input_mux_state_d       = enabled_channels;
      end
    end
  end // always_comb

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      input_mux_state_q          <= '0;
    end else begin
      input_mux_state_q          <= input_mux_state_d;
    end
  end

  ////////////////////////////////////////////////////////////////////////////
  //   ____   __  __          _     _____                                _  //
  //  / __ \ / _|/ _|        | |   |  __ \                              | | //
  // | |  | | |_| |_ ___  ___| |_  | |__) |___ _ __ ___   _____   ____ _| | //
  // | |  | |  _|  _/ __|/ _ \ __| |  _  // _ \ '_ ` _ \ / _ \ \ / / _` | | //
  // | |__| | | | | \__ \  __/ |_  | | \ \  __/ | | | | | (_) \ V / (_| | | //
  //  \____/|_| |_| |___/\___|\__| |_|  \_\___|_| |_| |_|\___/ \_/ \__,_|_| //
  ////////////////////////////////////////////////////////////////////////////

  logic signed [DATA_WIDTH-1:0]             offset_ema_input;
  logic signed [DATA_WIDTH-1:0]             offset_ema_output;
  logic                                     offset_ema_reg_en[NR_CHANNELS];
  logic signed [DATA_WIDTH-1:0]             offset_ema_d[NR_CHANNELS], offset_ema_q[NR_CHANNELS];
  logic signed [DATA_WIDTH+ALPHA_WIDTH+1:0] offset_ema_sum;

  assign offset_ema_input = (idata_i<<channel_config_q[active_channel_idx].input_shift_left) + channel_pre_offset_q[active_channel_idx]; //Add channel pre-offset and apply input shift left

  for (genvar i = 0; i < NR_CHANNELS; i++) begin :offset_rem_stage
    assign offset_ema_reg_en[i] = pipeline_enable & active_channel[i] & channel_config_q[i].offset_removal_en;

    always_comb begin
      offset_ema_d[i] = offset_ema_q[i];
      if (preprocessor_reset) begin
        offset_ema_d[i] = '0;
      end else if (offset_ema_reg_en[i]) begin
        offset_ema_d[i] = offset_ema_sum[DATA_WIDTH+ALPHA_WIDTH-1:ALPHA_WIDTH];
      end
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni) begin
        offset_ema_q[i] <= '0;
      end else begin
        offset_ema_q[i] <= offset_ema_d[i];
      end
    end
  end // for (genvar i = 0; i < NR_CHANNELS; i++)

  always_comb begin : offrem_comb
    logic signed [ALPHA_WIDTH:0]              alpha; //With leading zero
    logic signed [ALPHA_WIDTH:0]              one_minus_alpha;
    logic signed [DATA_WIDTH+ALPHA_WIDTH:0]   in_times_alpha;
    logic signed [DATA_WIDTH+ALPHA_WIDTH:0]   prev_times_alpha_min_one;
    logic signed [DATA_WIDTH+ALPHA_WIDTH+1:0] sum;
    alpha                    = channel_config_q[active_channel_idx].offset_removal_alpha;
    one_minus_alpha          = {1'b0, ~channel_config_q[active_channel_idx].offset_removal_alpha+1'b1};
    in_times_alpha           = alpha * offset_ema_input;
    prev_times_alpha_min_one = one_minus_alpha * offset_ema_q[active_channel_idx];
    offset_ema_sum           = in_times_alpha + prev_times_alpha_min_one;
  end // always_comb

  assign offremstage_rmsstage_data = (channel_config_q[active_channel_idx].offset_removal_en) ? offset_ema_input - offset_ema_q[active_channel_idx]: offset_ema_input;

  /////////////////////////////////////////////////////////
  //  _____  __  __  _____    _____ _                    //
  // |  __ \|  \/  |/ ____|  / ____| |                   //
  // | |__) | \  / | (___   | (___ | |_ __ _  __ _  ___  //
  // |  _  /| |\/| |\___ \   \___ \| __/ _` |/ _` |/ _ \ //
  // | | \ \| |  | |____) |  ____) | || (_| | (_| |  __/ //
  // |_|  \_\_|  |_|_____/  |_____/ \__\__,_|\__, |\___| //
  //                                          __/ |      //
  //                                         |___/       //
  /////////////////////////////////////////////////////////

  logic signed [DATA_WIDTH-1:0]             rms_ema_input;
  logic signed [DATA_WIDTH-1:0]             rms_ema_output;
  logic                                     rms_ema_reg_en[NR_CHANNELS];
  logic signed [DATA_WIDTH-1:0]             rms_ema_d[NR_CHANNELS], rms_ema_q[NR_CHANNELS];
  logic signed [DATA_WIDTH*2-1:0]           squared_input;
  logic signed [DATA_WIDTH+ALPHA_WIDTH+1:0] rms_ema_sum;

  assign squared_input = offremstage_rmsstage_data*offremstage_rmsstage_data;
  assign rms_ema_input = squared_input[DATA_WIDTH*2-2:DATA_WIDTH-1];

  for (genvar i = 0; i < NR_CHANNELS; i++) begin :rms_stage
    assign rms_ema_reg_en[i] = pipeline_enable & active_channel[i] & channel_config_q[i].rms_en;

    always_comb begin
      rms_ema_d[i] = rms_ema_q[i];
      if (preprocessor_reset) begin
        rms_ema_d[i] = '0;
      end else if (rms_ema_reg_en[i]) begin
        rms_ema_d[i] = rms_ema_sum[DATA_WIDTH+ALPHA_WIDTH-1:ALPHA_WIDTH];
      end
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni) begin
        rms_ema_q[i] <= '0;
      end else begin
        rms_ema_q[i] <= rms_ema_d[i];
      end
    end
  end // for (genvar i = 0; i < NR_CHANNELS; i++)

  always_comb begin :rms_comb
    logic signed [ALPHA_WIDTH:0]              alpha; //With leading zero
    logic signed [ALPHA_WIDTH:0]              one_minus_alpha;
    logic signed [DATA_WIDTH+ALPHA_WIDTH:0]   in_times_alpha;
    logic signed [DATA_WIDTH+ALPHA_WIDTH:0]   prev_times_alpha_min_one;
    logic signed [DATA_WIDTH+ALPHA_WIDTH+1:0] sum;
    alpha                    = channel_config_q[active_channel_idx].rms_alpha;
    one_minus_alpha          = {1'b0, ~channel_config_q[active_channel_idx].rms_alpha+1'b1};
    in_times_alpha           = alpha * rms_ema_input;
    prev_times_alpha_min_one = one_minus_alpha * rms_ema_q[active_channel_idx];
    rms_ema_sum           = in_times_alpha + prev_times_alpha_min_one;
  end // always_comb

  //Bypass if rms is disabled for channel i
  assign rmsstage_subsampl_data = (channel_config_q[active_channel_idx].rms_en) ? rms_ema_q[active_channel_idx] : offremstage_rmsstage_data;

  ////////////////////////////////////////////////////////
  //  _      ____  _____     _____ _                    //
  // | |    |  _ \|  __ \   / ____| |                   //
  // | |    | |_) | |__) | | (___ | |_ __ _  __ _  ___  //
  // | |    |  _ <|  ___/   \___ \| __/ _` |/ _` |/ _ \ //
  // | |____| |_) | |       ____) | || (_| | (_| |  __/ //
  // |______|____/|_|      |_____/ \__\__,_|\__, |\___| //
  //                                         __/ |      //
  //                                        |___/       //
  ////////////////////////////////////////////////////////
  logic                  lbp_en [NR_CHANNELS];
  logic [DATA_WIDTH-1:0] lbp_input[NR_CHANNELS];

  for (genvar i = 0; i < NR_CHANNELS; i++) begin :lbp_stage
    assign lbp_en[i] = pipeline_enable & active_channel[i] & channel_config_q[i].use_lbp;
    assign lbp_input[i] = idata_i + channel_pre_offset_q[i];

    lbp #(.CODEZIZE(LBP_CODESIZE), .DATA_WIDTH(DATA_WIDTH)) i_lbp
    (
     .clk_i,
     .rst_ni,
     .clear_i(preprocessor_reset),
     .en_i(lbp_en[i]),
     .data_i(lbp_input[i]),
     .lbp_o(lbp_subsampl_data[i]),
     .lbp_valid_o(lbp_subsampl_valid[i])
     );
  end

  ////////////////////////////////////////////////////////////////////
  //   _____       _                               _ _              //
  //  / ____|     | |                             | (_)             //
  // | (___  _   _| |__  ___  __ _ _ __ ___  _ __ | |_ _ __   __ _  //
  //  \___ \| | | | '_ \/ __|/ _` | '_ ` _ \| '_ \| | | '_ \ / _` | //
  //  ____) | |_| | |_) \__ \ (_| | | | | | | |_) | | | | | | (_| | //
  // |_____/ \__,_|_.__/|___/\__,_|_| |_| |_| .__/|_|_|_| |_|\__, | //
  //                                        | |               __/ | //
  //                                        |_|              |___/  //
  //   _____ _                                                      //
  //  / ____| |                                                     //
  // | (___ | |_ __ _  __ _  ___                                    //
  //  \___ \| __/ _` |/ _` |/ _ \                                   //
  //  ____) | || (_| | (_| |  __/                                   //
  // |_____/ \__\__,_|\__, |\___|                                   //
  //                   __/ |                                        //
  //                  |___/                                         //
  ////////////////////////////////////////////////////////////////////
  logic [SUBSAMPLING_WITH-1:0] subsampling_counter_d, subsampling_counter_q;

  //Subsampling Counter
  always_comb begin
    subsampling_counter_d  = subsampling_counter_q;
    if (preprocessor_reset) begin
      subsampling_counter_d = '0;
    end else if (pipeline_enable & is_last_enabled_channel) begin
      if (subsampling_counter_q != cfg_reg_subsampling_q) begin
        subsampling_counter_d = subsampling_counter_q + 1;
      end else begin
        subsampling_counter_d = '0;
      end
    end
  end // always_comb

  //Push signal for output FIFO
  always_comb begin
    for (int i = 0; i < NR_CHANNELS; i++) begin
      if (subsampling_counter_q == '0) begin
        if (channel_config_q[i].use_lbp) begin
          subsampling_ofifo_push[i] = active_channel[i] & pipeline_enable & lbp_subsampl_valid[i];
        end else begin
          subsampling_ofifo_push[i] = active_channel[i] & pipeline_enable;
        end
      end else begin
        subsampling_ofifo_push[i] = 1'b0;
      end
    end
  end

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      subsampling_counter_q <= '0;
    end else begin
      subsampling_counter_q <= subsampling_counter_d;
    end
  end

  //Multiplex between LBP and RMS stage
  logic [DATA_WIDTH-1:0] rmsstage_subsampl_data_offset_shifted;
  assign rmsstage_subsampl_data_offset_shifted = (rmsstage_subsampl_data + channel_post_offset_q[active_channel_idx])>>channel_config_q[active_channel_idx].output_shift_right;
  assign subsampling_ofifo_data = (channel_config_q[active_channel_idx].use_lbp) ? lbp_subsampl_data[active_channel_idx] : rmsstage_subsampl_data_offset_shifted;

  ////////////////////////////////////////////////////////////////////
  //   ____        _               _     ______ _____ ______ ____   //
  //  / __ \      | |             | |   |  ____|_   _|  ____/ __ \  //
  // | |  | |_   _| |_ _ __  _   _| |_  | |__    | | | |__ | |  | | //
  // | |  | | | | | __| '_ \| | | | __| |  __|   | | |  __|| |  | | //
  // | |__| | |_| | |_| |_) | |_| | |_  | |     _| |_| |   | |__| | //
  //  \____/ \__,_|\__| .__/ \__,_|\__| |_|    |_____|_|    \____/  //
  //                  | |                                           //
  //                  |_|                                           //
  ////////////////////////////////////////////////////////////////////
  logic [NR_CHANNELS-1:0] ofifo_pop;

  for (genvar i = 0; i < NR_CHANNELS; i++) begin : output_fifo
    assign ofifo_pop[i] = odata_ack_sample_i & enabled_channels[i];

    fifo_v3 #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(FIFO_DEPTH))
    i_ofifo
                  (
                   .clk_i,
                   .rst_ni,
                   .flush_i(preprocessor_reset),
                   .testmode_i,
                   .full_o(ofifo_full[i]),
                   .empty_o(ofifo_empty[i]),
                   .data_i(subsampling_ofifo_data),
                   .push_i(subsampling_ofifo_push[i]),
                   .data_o(ofifo_outmux_data[i]),
                   .pop_i(ofifo_pop[i]),
                   .usage_o()
                   );
  end

  ///////////////////////////////////////////////////////
  //   ____        _               _                   //
  //  / __ \      | |             | |                  //
  // | |  | |_   _| |_ _ __  _   _| |_                 //
  // | |  | | | | | __| '_ \| | | | __|                //
  // | |__| | |_| | |_| |_) | |_| | |_                 //
  //  \____/ \__,_|\__| .__/ \__,_|\__|                //
  //                  | |                              //
  //                  |_|                              //
  //  __  __       _ _   _       _                     //
  // |  \/  |     | | | (_)     | |                    //
  // | \  / |_   _| | |_ _ _ __ | | _____  _____ _ __  //
  // | |\/| | | | | | __| | '_ \| |/ _ \ \/ / _ \ '__| //
  // | |  | | |_| | | |_| | |_) | |  __/>  <  __/ |    //
  // |_|  |_|\__,_|_|\__|_| .__/|_|\___/_/\_\___|_|    //
  //                      | |                          //
  //                      |_|                          //
  ///////////////////////////////////////////////////////

  //One-hot encoding of active channel. e.g. 0b0100 -> channel with idx=2 is
  //active
  logic [NR_CHANNELS-1:0] output_mux_state_d, output_mux_state_q;

  always_comb begin
    output_mux_state_d = output_mux_state_q;
    selected_channel   = '0;

    for (int i = NR_CHANNELS-1; i >= 0; i--) begin
      if (output_mux_state_q[i]) begin
        selected_channel    = '0;
        selected_channel[i] = 1'b1;
      end
    end

    if (preprocessor_reset) begin
      output_mux_state_d = enabled_channels;
    end else if (odata_switch_channel_i) begin
      output_mux_state_d = output_mux_state_q ^ selected_channel;
      if ((output_mux_state_q ^ selected_channel) == '0) begin
        output_mux_state_d = enabled_channels;
      end
    end
  end // always_comb

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      output_mux_state_q <= '0;
    end else begin
      output_mux_state_q <= output_mux_state_d;
    end
  end


  //-------------------- Output Assignments --------------------
  always_comb begin
    if (selected_channel == '0) begin
      odata_valid_o = 1'b0;
    end else begin
      odata_valid_o = ~|(ofifo_empty & selected_channel);
    end
  end

  always_comb begin
    odata_o = 'X;
    for (int i = 0; i < NR_CHANNELS; i++) begin
      if (selected_channel[i]) begin
        odata_o = ofifo_outmux_data[i];
      end
    end
  end


endmodule : preprocessor_top

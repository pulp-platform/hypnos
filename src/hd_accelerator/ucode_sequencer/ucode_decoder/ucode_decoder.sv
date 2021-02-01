//-----------------------------------------------------------------------------
// Title         : uCode Decoder
//-----------------------------------------------------------------------------
// File          : ucode_decoder.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 10.10.2018
//-----------------------------------------------------------------------------
// Description :
// This module decodes the input instructions in the uCode sequencer.
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

module ucode_decoder
  import pkg_common::*;
  import pkg_ucode_decoder::*;
  (
   input logic                            clk_i,
   input logic                            rst_ni,
   input logic                            en_i,
   input instruction_t                    instruction_i,
   input logic                            instruction_valid_i,
   output logic                           flush_pipeline_o,
   //Register inputs
   input pkg_ucode_sequencer::offset_t    offset_cntr_i,

   //AM module
   input logic                            hd_mem_am_search_valid_i,
   input logic                            hd_mem_am_search_is_min_i,
   input vector_idx_t                     hd_mem_am_search_result_idx_i,
   input hamming_distance_t               hd_mem_am_search_distance_i,

   //Input data
   input logic [PREPROC_DATA_WIDTH-1:0]   idata_i,
   input logic                            idata_valid_i,
   output logic                           idata_switch_channel_o,
   output logic                           idata_ack_sample_o,

   //Host interrupt
   input logic                            host_clr_intr_i,
   output logic                           host_intr_o,

   //Result register output
   output vector_idx_t                    result_reg_idx_o,
   output hamming_distance_t              result_reg_distance_o,


   //Stall signals
   //--------------------- Control Signals ---------------------
   //AM-Search Module
   output logic                           hd_mem_am_search_start_o,
   output logic                           hd_mem_am_search_stall_o,
   output vector_idx_t                    hd_mem_am_search_end_idx_o,

   //PC HW loop module
   output logic                           ready_o,
   output logic                           pc_we_o,
   output im_addr_t                       pc_wdata_o,
   output logic                           pc_hwl_we_o,
   output logic [HWL_SEL_WIDTH-1:0]       pc_hwl_sel_o,
   output hwl_iterations_t                pc_hwl_iterations_o,
   output im_addr_t                       pc_hwl_end_addr_o,

   //HD-memory
   output logic                           hd_mem_we_o,
   output pkg_hd_memory::write_mode_t     hd_mem_write_mode_o,
   output vector_idx_t                    hd_mem_vector_read_idx_o,
   output vector_idx_t                    hd_mem_vector_write_idx_o,

   //HD-encoder
   output logic                           enc_mixer_en_o,
   output logic                           enc_mixer_inverse_o,
   output logic                           enc_mixer_perm_sel_o,
   output pkg_hd_encoder::input_sel_t     enc_input_sel_o,
   output logic                           enc_man_en_o,
   output pkg_hd_encoder::man_value_sel_t enc_man_value_sel_o,
   output pkg_hd_unit::operand_sel_e      enc_op_sel_o,
   output logic                           enc_bundle_cntr_en_o,
   output logic                           enc_bundle_cntr_rst_o,
   output pkg_hd_unit::bundle_ctx_idx_t   enc_bundle_ctx_idx_o,
   output logic                           enc_bundle_ctx_we_o,
   output logic                           enc_bundle_ctx_add_o,

   //Offset Counter
   output logic                           offset_cntr_clr_o,
   output logic                           offset_cntr_en_o,
   output logic                           offset_cntr_dir_o, //1: count upwards, 0: count downwards

   //Internal MAN value
   output logic                           man_value_reg_we_o,
   output man_value_t                     man_value_reg_o
    );
  localparam bit                           IS_FOLDED = ROWS_PER_HDVECT > 1;

  typedef enum logic[2:0]                             {Decode, Interrupt, AMSearch, Mixing, StoreBundleCtx, LoadBundleCtx, AddBundleCtx} state_e;
  localparam MIXER_VALUE_WIDTH = PREPROC_DATA_WIDTH;
  localparam MIXER_VALUE_LENGTH_WIDTH = $clog2(MIXER_VALUE_WIDTH);

  //Registers
  state_e                              state_d,                state_q;
  logic [MIXER_VALUE_LENGTH_WIDTH-1:0] mixer_value_length_d,   mixer_value_length_q;
  logic [MIXER_VALUE_WIDTH-1:0]        mixer_value_shiftreg_d, mixer_value_shiftreg_q;
  pkg_hd_unit::bundle_ctx_idx_t        bundle_ctx_idx_d,       bundle_ctx_idx_q;
  vector_idx_t                         result_idx_d,           result_idx_q;
  hamming_distance_t                   result_distance_d,      result_distance_q;

  assign result_reg_idx_o      = result_idx_q;
  assign result_reg_distance_o = result_distance_q;

  always_comb
    begin
      //------------------- Default assignemnts -------------------
      state_d                    = state_q;
      flush_pipeline_o           = 1'b0;

      //AM-Search Module
      hd_mem_am_search_start_o   = 1'b0;
      hd_mem_am_search_stall_o   = 1'b0;
      hd_mem_am_search_end_idx_o = 0;

      //PC HW loop module
      ready_o                    = 1'b1; //Program Counter enabled by default
      pc_we_o                    = 1'b0;
      pc_wdata_o                 = 'X;
      pc_hwl_we_o                = 1'b0;
      pc_hwl_sel_o               = 'X;
      pc_hwl_iterations_o        = 'X;
      pc_hwl_end_addr_o          = 'X;

       //HD-memory
      hd_mem_we_o                = 1'b0;
      hd_mem_write_mode_o        = pkg_hd_memory::RowMode;
      hd_mem_vector_read_idx_o   = 'X;
      hd_mem_vector_write_idx_o  = 'X;

       //HD-encoder
      enc_mixer_en_o             = 1'b0;
      enc_mixer_inverse_o        = 'X;
      enc_mixer_perm_sel_o       = 'X;
      enc_input_sel_o            = pkg_hd_encoder::input_sel_t'('X);
      enc_man_en_o               = 1'b0;
      enc_man_value_sel_o        = pkg_hd_encoder::man_value_sel_t'('X);
      enc_op_sel_o               = pkg_hd_unit::NOP;
      enc_bundle_cntr_en_o       = 1'b0;
      enc_bundle_cntr_rst_o      = 1'b0;
      enc_bundle_ctx_idx_o       = 'X;
      enc_bundle_ctx_we_o        = 1'b0;
      enc_bundle_ctx_add_o       = 1'b0;
      bundle_ctx_idx_d           = bundle_ctx_idx_q;

      //External Data
      idata_switch_channel_o     = 1'b0;
      idata_ack_sample_o         = 1'b0;

      //Offset Counter
      offset_cntr_clr_o          = 1'b0;
      offset_cntr_en_o           = 1'b0;
      offset_cntr_dir_o          = 1'bX;


      //Internal MAN value
      man_value_reg_we_o         = 1'b0;
      man_value_reg_o            = 'X;

      //Host interrupt
      host_intr_o                = 1'b0;

      //IM mapping
      mixer_value_length_d       = mixer_value_length_q;
      mixer_value_shiftreg_d     = mixer_value_shiftreg_q;

      //Result registers
      result_idx_d               = result_idx_q;
      result_distance_d          = result_distance_q;

       if (en_i) begin
         unique case(state_q)
           Decode: begin
             if (instruction_valid_i) begin
                            //Distinguish between hd_encoder configuration instructions  and normal instructions
               unique case (instruction_i.instr_class)
                 NISC:
                   begin
                     //First test wether we need to access shared memory. If yes, make sure the data is valid otherwise stall by disabling the programm counter.
                     if (instruction_i.instruction.nisc_instr.man_value_sel == pkg_hd_encoder::EXTERNAL) begin
                       if (idata_valid_i) begin
                         //update the address (will be increased by value in stride reg and starts a new read request)
                         idata_switch_channel_o = 1'b1;
                       end else begin
                         ready_o = 1'b0;
                       end
                     end
                     //Assign the configuration values to the encoder control outputs
                     enc_mixer_en_o            = instruction_i.instruction.nisc_instr.mixer_en;
                     enc_mixer_inverse_o       = instruction_i.instruction.nisc_instr.mixer_inverse;
                     enc_mixer_perm_sel_o      = instruction_i.instruction.nisc_instr.mixer_perm_sel;
                     enc_input_sel_o           = instruction_i.instruction.nisc_instr.enc_input_sel;
                     enc_man_en_o              = instruction_i.instruction.nisc_instr.man_en;
                     enc_man_value_sel_o       = instruction_i.instruction.nisc_instr.man_value_sel;
                     enc_op_sel_o              = instruction_i.instruction.nisc_instr.hd_op_sel;
                     enc_bundle_cntr_en_o      = instruction_i.instruction.nisc_instr.bundler_en;
                     enc_bundle_cntr_rst_o     = instruction_i.instruction.nisc_instr.bundler_rst;
                     hd_mem_we_o               = instruction_i.instruction.nisc_instr.write_back_en;
                     hd_mem_vector_read_idx_o  = instruction_i.instruction.nisc_instr.vector_read_idx[VECTOR_IDX_WIDTH-1:0];
                     hd_mem_vector_write_idx_o = instruction_i.instruction.nisc_instr.vector_write_idx[VECTOR_IDX_WIDTH-1:0];
                   end
                 RISC:
                   begin
                     unique case (instruction_i.instruction.risc_instr.type2_instr.opcode)
                       OP_NOP: begin
                       end

                       OP_INTRPT: begin
                         //Assert if the interrupt condition is true
                         // result index < first operand && result_distance < second_operand
                         if (result_idx_q < instruction_i.instruction.risc_instr.type3_instr.length && result_distance_q < instruction_i.instruction.risc_instr.type3_instr.operand) begin
                           //Assert interrupt signal
                           host_intr_o = 1'b1;
                           //Check if clear interrup signal is asserted. If not, stop programm counter
                           if (host_clr_intr_i != 1'b1) begin
                             ready_o          = 1'b0;
                             flush_pipeline_o = 1'b1;
                             state_d          = Interrupt;
                           end
                         end
                       end

                       OP_JMP: begin
                         //overwrite pc value
                         pc_wdata_o       = instruction_i.instruction.risc_instr.type2_instr.operand[IM_ADDR_WIDTH-1:0];
                         pc_we_o          = 1'b1;
                         flush_pipeline_o = 1'b1;
                       end

                       OP_CLR_OFFSET: begin
                         offset_cntr_clr_o = 1'b1;
                       end

                       OP_INC_OFFSET: begin
                         offset_cntr_dir_o = 1'b1;
                         offset_cntr_en_o  = 1'b1;
                       end

                       OP_DEC_OFFSET: begin
                         offset_cntr_dir_o = 1'b0;
                         offset_cntr_en_o  = 1'b1;
                       end

                       OP_ACK_SAMPLE: begin
                         idata_ack_sample_o = 1'b1;
                       end

                       OP_LOOP_SETUP0: begin
                         pc_hwl_sel_o        = 0;
                         pc_hwl_iterations_o = instruction_i.instruction.risc_instr.type1_instr.operand_a;
                         pc_hwl_end_addr_o   = instruction_i.instruction.risc_instr.type1_instr.operand_b[IM_ADDR_WIDTH-1:0];
                         pc_hwl_we_o         = 1'b1;
                       end

                       OP_LOOP_SETUP1: begin
                         pc_hwl_sel_o = 1;
                         pc_hwl_iterations_o = instruction_i.instruction.risc_instr.type1_instr.operand_a;
                         pc_hwl_end_addr_o = instruction_i.instruction.risc_instr.type1_instr.operand_b[IM_ADDR_WIDTH-1:0];
                         pc_hwl_we_o = 1'b1;
                       end

                       OP_LOOP_SETUP2: begin
                         pc_hwl_sel_o = 2;
                         pc_hwl_iterations_o = instruction_i.instruction.risc_instr.type1_instr.operand_a;
                         pc_hwl_end_addr_o = instruction_i.instruction.risc_instr.type1_instr.operand_b[IM_ADDR_WIDTH-1:0];
                         pc_hwl_we_o = 1'b1;
                       end

                       OP_AM_SEARCH: begin
                         hd_mem_am_search_start_o = 1'b1;
                         ready_o                  = 1'b0;
                         flush_pipeline_o         = 1'b1;
                         state_d                  = AMSearch;
                       end

                       OP_SET_MAN_VALUE: begin
                         man_value_reg_o = instruction_i.instruction.risc_instr.type2_instr.operand[MAN_VALUE_WIDTH-1:0];
                         man_value_reg_we_o = 1'b1;
                       end

                       OP_MIX_IMMEDIATE: begin
                         ready_o                = 1'b0;
                         //Load the operands (operand and length of operand) and switch to mixing state
                         state_d                = Mixing;
                         mixer_value_length_d   = instruction_i.instruction.risc_instr.type3_instr.length;
                         mixer_value_shiftreg_d = instruction_i.instruction.risc_instr.type3_instr.operand;
                       end

                       OP_MIX_EXT: begin
                         ready_o                = 1'b0;
                         if (idata_valid_i) begin
                           //Switch to the next channel
                           idata_switch_channel_o = 1'b1;
                           //Load the length of the value from the immediate part but use the value from SMI.
                           state_d                = Mixing;
                           mixer_value_length_d   = instruction_i.instruction.risc_instr.type2_instr.operand[MIXER_VALUE_LENGTH_WIDTH-1:0];
                           mixer_value_shiftreg_d = idata_i;
                         end
                       end

                       OP_MIX_OFFSET: begin
                         //There is no offset in the unfolded architecture
                         if (IS_FOLDED) begin
                           ready_o                = 1'b0;
                           //Use the current offset for mixing
                           state_d                = Mixing;
                           mixer_value_length_d   = unsigned'($clog2(ROWS_PER_HDVECT));
                           mixer_value_shiftreg_d = offset_cntr_i;
                         end
                       end

                       OP_STORE_BNDL_CTX: begin
                         ready_o          = 1'b0;
                         state_d          = StoreBundleCtx;
                         bundle_ctx_idx_d = '0;
                       end

                       OP_LOAD_BNDL_CTX: begin
                         ready_o = 1'b0;
                         state_d = LoadBundleCtx;
                         bundle_ctx_idx_d = '0;
                       end

                       OP_ADD_BNDL_CTX: begin
                         ready_o          = 1'b0;
                         state_d          = AddBundleCtx;
                         enc_op_sel_o     = pkg_hd_unit::BUNDLE;
                         bundle_ctx_idx_d = '0;
                       end
                       default: begin
                         $display("Reached illegal instruction %h", instruction_i.instruction.risc_instr.type2_instr.opcode);
                       end
                     endcase
                   end // case: RISC
                 default: begin
                   $display("Reached illegal instruction %h", instruction_i.instruction.risc_instr.type2_instr.opcode);
                 end
               endcase
             end
           end // case: Decode

           Interrupt: begin
             //Assert interrupt signal
             host_intr_o = 1'b1;
             //Check if clear interrup signal is asserted. If not, stop programm
             //counter and flush the pipeline.
             if (host_clr_intr_i == 1'b1) begin
               ready_o = 1'b1;
               state_d = Decode;
             end else begin
               ready_o          = 1'b0;
               flush_pipeline_o = 1'b1;
             end
           end // case: Interrupt

           AMSearch: begin
             hd_mem_am_search_end_idx_o = vector_idx_t'(instruction_i.instruction.risc_instr.type1_instr.operand_b);
             hd_mem_am_search_start_o   = 1'b1;
             if (hd_mem_am_search_is_min_i) begin
               //Store the result in the result register.
               result_idx_d      = hd_mem_am_search_result_idx_i;
               result_distance_d = hd_mem_am_search_distance_i;
               //Switch back to the Decode state
               ready_o           = 1'b1;
               state_d           = Decode;
             end else begin
               //Wait for the AM search to finish
               ready_o          = 1'b0;
               flush_pipeline_o = 1'b1;
             end
           end // case: AMSearch

           StoreBundleCtx: begin
             //Store the bundle context in 5 hd-vector slots starting at vector_idx == operand.
             //The current value of offset_cntr is used to determine which row to use within the hd-vector slot
             hd_mem_vector_write_idx_o = instruction_i.instruction.risc_instr.type2_instr.operand[VECTOR_IDX_WIDTH-1:0] + bundle_ctx_idx_q;
             hd_mem_we_o               = 1'b1;
             enc_op_sel_o              = pkg_hd_unit::BUNDLE_CTX;
             enc_bundle_ctx_idx_o      = bundle_ctx_idx_q;
             //Check whether we are done
             if (bundle_ctx_idx_q == unsigned'(pkg_common::BUNDLE_CNTR_WIDTH-1)) begin
               state_d = Decode;
               ready_o = 1'b1;
             end else begin
               //Stay in this state and increment the index counter
               ready_o          = 1'b0;
               bundle_ctx_idx_d = bundle_ctx_idx_q + 1;
             end
           end // case: StoreBundleCtx

           LoadBundleCtx: begin
             //Load the bundle context from 5 hd-vector slots starting at vector_idx == operand.
             //The current value of offset_cntr is used to determine which row to use within the hd-vector slot
             hd_mem_vector_read_idx_o = instruction_i.instruction.risc_instr.type2_instr.operand[VECTOR_IDX_WIDTH-1:0] + bundle_ctx_idx_q;
             enc_op_sel_o             = pkg_hd_unit::NOP;
             enc_bundle_ctx_idx_o     = bundle_ctx_idx_q;
             enc_bundle_ctx_we_o      = 1'b1;
             enc_mixer_en_o           = 1'b0;
             enc_input_sel_o          = pkg_hd_encoder::MEMORY;
             enc_man_value_sel_o      = pkg_hd_encoder::INTERNAL;
             //Check whether we are done
             if (bundle_ctx_idx_q == unsigned'(pkg_common::BUNDLE_CNTR_WIDTH-1)) begin
               state_d = Decode;
               ready_o = 1'b1;
             end else begin
               //Stay in this state and increment the index counter
               ready_o = 1'b0;
               bundle_ctx_idx_d = bundle_ctx_idx_q + 1;
             end
           end // case: LoadBundleCtx

           AddBundleCtx: begin
             //Load the bundle context from 5 hd-vector slots starting at vector_idx == operand.
             //The current value of offset_cntr is used to determine which row to use within the hd-vector slot
             hd_mem_vector_read_idx_o = instruction_i.instruction.risc_instr.type2_instr.operand[VECTOR_IDX_WIDTH-1:0] + bundle_ctx_idx_q;
             enc_op_sel_o             = pkg_hd_unit::NOP;
             enc_bundle_ctx_idx_o     = bundle_ctx_idx_q;
             enc_bundle_ctx_we_o      = 1'b0;
             enc_bundle_ctx_add_o     = 1'b1;
             enc_mixer_en_o           = 1'b0;
             enc_input_sel_o          = pkg_hd_encoder::MEMORY;
             enc_man_value_sel_o      = pkg_hd_encoder::INTERNAL;
             //Check whether we are done
             if (bundle_ctx_idx_q == unsigned'(pkg_common::BUNDLE_CNTR_WIDTH-1)) begin
               state_d = Decode;
               ready_o = 1'b1;
             end else begin
               //Stay in this state and increment the index counter
               ready_o = 1'b0;
               bundle_ctx_idx_d = bundle_ctx_idx_q + 1;
             end
           end

           Mixing: begin
             ready_o              = 1'b0;
             //Perform one mixing round
             enc_input_sel_o      = pkg_hd_encoder::OUTPUT_REG;
             enc_man_value_sel_o  = pkg_hd_encoder::INTERNAL;
             enc_op_sel_o         = pkg_hd_unit::PASSTHROUGH;
             enc_mixer_en_o       = 1'b1;
             enc_mixer_inverse_o  = 1'b0;
             enc_mixer_perm_sel_o = mixer_value_shiftreg_q[0];
             //Check whether  we are done mixing
             if (mixer_value_length_q == 1) begin
               //We are done mixing. Clear the registers and proceed decoding the next
               mixer_value_length_d   = '0;
               mixer_value_shiftreg_d = '0;
               ready_o                = 1'b1;
               state_d                = Decode;
             end else begin
               mixer_value_length_d = mixer_value_length_q - 1;
               mixer_value_shiftreg_d = mixer_value_shiftreg_q>>1;
             end
           end // case: Mixing

           default: begin
             state_d = Decode;
           end
         endcase
       end
    end // always_comb

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (!rst_ni) begin
      state_q                <= Decode;
      mixer_value_length_q   <= '0;
      mixer_value_shiftreg_q <= '0;
      bundle_ctx_idx_q       <= '0;
      result_idx_q           <= '0;
      result_distance_q      <= '0;
    end else begin
      state_q                <= state_d;
      mixer_value_length_q   <= mixer_value_length_d;
      mixer_value_shiftreg_q <= mixer_value_shiftreg_d;
      bundle_ctx_idx_q       <= bundle_ctx_idx_d;
      result_idx_q           <= result_idx_d;
      result_distance_q      <= result_distance_d;
    end
  end // always_ff @ (posedge clk_i, negedge rst_ni)

endmodule : ucode_decoder

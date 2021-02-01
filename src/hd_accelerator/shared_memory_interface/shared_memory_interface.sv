//-----------------------------------------------------------------------------
// Title         : Shared Memory Interface
//-----------------------------------------------------------------------------
// File          : shared_memory_interface.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 12.10.2018
//-----------------------------------------------------------------------------
// Description :
// This module contains the read and write address registers for accesses to
// shared memory. To write data to shared memory, the data has to be applied
// to the corresponding input and the write request signal has to be asserted.
// The data needs to remain stable until the write grant output signals goes to
// high. Read access however is handled transparently (to reduce latency).
// Whenever the internal read address is modified, the valid flag is cleared and
// a new read transaction is started automatically. As soon as the transaction
// succeeded the valid flag is set again.
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

module smi
  import pkg_common::*;
  (
   input logic                clk_i,
   input logic                rst_ni,
   input logic                clear_i, //Synchronous reset. Necessary since the smi could block infinitely if we try to read/write with an invalid address. (No gnt will ever be received.)
   //--------------- Signals from HD-Accelerator ---------------
   input logic                write_req_i,
   output logic               write_gnt_o,
   input word_t               write_data_i,
   output word_t              read_data_o,
   output logic               read_data_valid_o,
   //----------- Signals to Logarithmic Interconnect -----------
   output logic               li_req_o,
   output logic               li_we_o,
   input logic                li_gnt_i,
   input logic                li_rvalid_i,
   output shared_mem_addr_t   li_addr_o,
   input word_t               li_rdata_i,
   output word_t              li_wdata_o,
   //----------------- Read Address Register Signals -----------------
   input logic                raddr_we_i,
   input logic                raddr_inc_i,
   input shared_mem_addr_t    raddr_i,
   output shared_mem_addr_t   raddr_o,
   input logic                raddr_stride_we_i,
   input shared_mem_stride_t  raddr_stride_i,
   output shared_mem_stride_t raddr_stride_o,
   //----------------- Write Address Register Signals -----------------
   input logic                waddr_we_i,
   input logic                waddr_inc_i,
   input shared_mem_addr_t    waddr_i,
   output shared_mem_addr_t   waddr_o,
   input logic                waddr_stride_we_i,
   input shared_mem_stride_t  waddr_stride_i,
   output shared_mem_stride_t waddr_stride_o
   );

   typedef enum               logic[2:0]               {AfterReset, Idle, ReadRequestPending, SampleData, WriteRequestPending} state_t;
   state_t                    state_d, state_q;
   logic                      valid_set, valid_rst;

   //Internal Registers
   shared_mem_addr_t                          raddr_d, raddr_q;
   shared_mem_stride_t                        raddr_stride_d, raddr_stride_q;
   shared_mem_addr_t                          waddr_d, waddr_q;
   shared_mem_stride_t                        waddr_stride_d, waddr_stride_q;
   logic                                      rvalid_d, rvalid_q;
   word_t                                     rdata_d, rdata_q;

   assign read_data_valid_o = rvalid_q;
   assign read_data_o = rdata_q;
   assign li_wdata_o = write_data_i;
   assign raddr_o = raddr_q;
   assign raddr_stride_o = raddr_stride_q;
   assign waddr_o = waddr_q;
   assign waddr_stride_o = waddr_stride_q;


   //Read address register
   always_comb
     begin
       priority if (raddr_we_i) begin
         raddr_d = raddr_i;
         valid_rst = 1'b1;
       end else if (raddr_inc_i) begin
         raddr_d = raddr_q + raddr_stride_q;
         valid_rst = 1'b1;
       end else begin
         raddr_d = raddr_q;
         valid_rst = 1'b0;
       end
     end

   //Valid flag
   always_comb
     begin
       if (valid_rst) //reset signal overrides set signal. Otherwise parallel reads from LI and change of address end up with wrong data shown as valid.
         rvalid_d = 1'b0;
       else if (valid_set)
         rvalid_d = 1'b1;
       else
         rvalid_d = rvalid_q;
     end

   //Read Address Stride Register
   assign raddr_stride_d = (raddr_stride_we_i)? raddr_stride_i : raddr_stride_q;

   //Write address register
   always_comb
     begin
       priority if (waddr_we_i) begin
         waddr_d   = waddr_i;
       end else if (waddr_inc_i) begin
         waddr_d   = waddr_q + waddr_stride_q;
       end else begin
         waddr_d   = waddr_q;
       end
     end

   //Write Address Stride Register
   assign waddr_stride_d = (waddr_stride_we_i)? waddr_stride_i : waddr_stride_q;

   //FSM
   always_comb
     begin
       state_d     = state_q;
       valid_set   = 0;
       write_gnt_o = 1'b0;
       rdata_d     = rdata_q;
       li_req_o    = 1'b0;
       li_we_o     = 1'b0;
       li_addr_o   = 'X;
       if (clear_i) begin
         state_d = AfterReset; //Go back to AfterReset state if we get a synchronous reset.
       end else begin
         unique case (state_q)
           AfterReset: begin
             //Stay in this state until a new read address is entered. Otherwise we might end up trying to read from an invalid address.
             if (raddr_we_i) state_d = Idle;
             else state_d = AfterReset; 
           end
           Idle: begin
             priority if (!rvalid_q) begin
               state_d = ReadRequestPending;
             end else if (write_req_i) begin
               //Start the write transaction
               li_we_o = 1'b1;
               li_req_o = 1'b1;
               li_addr_o = waddr_q;
               //Switch to waiting state if we do not immediately get the grant signal
               if (li_gnt_i == 1'b0) begin
                 state_d = WriteRequestPending;
               end else begin
                 //Forward the grant signal and stay in Idle mode
                 write_gnt_o = 1'b1;
                 state_d = Idle;
               end
             end else begin
               state_d = Idle;
             end
           end

           WriteRequestPending: begin
             li_req_o = 1;
             li_we_o = 1'b1;
             li_addr_o = waddr_q;
             priority if (li_gnt_i) begin
               //Received grant form LI. Forwarding the signal and returning to idle
               state_d     = Idle;
               write_gnt_o = 1'b1;
             end else if (!write_req_i) begin
               //write request wass illegaly removed. Returning to idle without asserting grant signal
               state_d = Idle;
             end else begin
               //Stay in write request pending state
               state_d = WriteRequestPending;
             end
           end

           ReadRequestPending: begin
             //Start reading request
             li_we_o = 1'b0;
             li_req_o = 1'b1; 
             li_addr_o = raddr_q;
             //If we get the grant, proceed to sample the data into the rdata register
             if (li_gnt_i) begin
               state_d = SampleData;
             end else begin
               state_d = ReadRequestPending;
             end
           end

           SampleData: begin
             //Load the data read into the register and set the valid flag if we received the valid signal from the LI. 
             if (li_rvalid_i) begin
               valid_set = 1'b1;
             end else begin
               valid_set = 1'b0;
             end
             rdata_d   = li_rdata_i;
             state_d   = Idle;
           end

           default: begin
             state_d = Idle;
           end
         endcase
       end
     end

   always_ff @(posedge clk_i, negedge rst_ni)
     begin
       if (!rst_ni) begin
         rvalid_q       <= '0;
         rdata_q        <= '0;
         raddr_q        <= '0;
         raddr_stride_q <= '0;
         waddr_q        <= '0;
         waddr_stride_q <= '0;
         state_q        <= AfterReset;
       end else begin
         rvalid_q       <= rvalid_d;
         rdata_q        <= rdata_d;
         raddr_q        <= raddr_d;
         raddr_stride_q <= raddr_stride_d;
         waddr_q        <= waddr_d;
         waddr_stride_q <= waddr_stride_d;
         state_q        <= state_d;
       end
     end

endmodule : smi

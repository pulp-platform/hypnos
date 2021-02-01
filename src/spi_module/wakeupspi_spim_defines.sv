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

`define SPI_STD     2'b00
`define SPI_QUAD_TX 2'b10
`define SPI_QUAD_RX 2'b11

`define SPI_CMD_CFG       4'b0000
`define SPI_CMD_SOT       4'b0001
`define SPI_CMD_SEND_CMD  4'b0010

`define SPI_CMD_DUMMY     4'b0100
`define SPI_CMD_WAIT      4'b0101
`define SPI_CMD_TX_DATA   4'b0110
`define SPI_CMD_RX_DATA   4'b0111
`define SPI_CMD_RPT       4'b1000
`define SPI_CMD_EOT       4'b1001
`define SPI_CMD_RPT_END   4'b1010
`define SPI_CMD_RX_CHECK  4'b1011
`define SPI_CMD_FULL_DUPL 4'b1100
`define SPI_CMD_SETUP_UCA 4'b1101
`define SPI_CMD_SETUP_UCS 4'b1110

`define SPI_WAIT_EVT 2'b00
`define SPI_WAIT_CYC 2'b01
`define SPI_WAIT_GP  2'b10

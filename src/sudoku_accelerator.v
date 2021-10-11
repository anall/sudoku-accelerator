/* SPDX-FileCopyrightText: 2021 Andrea Nall

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
   SPDX-License-Identifier: Apache-2.0
*/
`default_nettype none
`timescale 1ns/1ns
module sudoku_accelerator (
  input wire wb_clk_i,
  input wire wb_rst_i,

  input [31:0]  wb_adr_i,
  input [31:0]  wb_dat_i,
  input [3:0]   wb_sel_i,
  input         wb_we_i,
  input         wb_cyc_i,
  input         wb_stb_i,

  output        wb_ack_o,
  output [31:0] wb_dat_o,

  output uart_enabled_n,
  output ser_tx,
  input ser_rx,

  output interrupt_sudoku,
  output interrupt_uart,

  output interrupt // for testbench use only
);


wire sudoku_addr = (wb_adr_i & 32'hFFF00000) == 32'h30000000;
wire uart_addr   = (wb_adr_i & 32'hFFF00000) == 32'h30800000;

wire sudoku_ack;
wire [31:0] sudoku_dat;

wire uart_ack;
wire [31:0] uart_dat;

wire uart_enabled;
assign uart_enabled_n = ~uart_enabled;

assign wb_ack_o = sudoku_addr ? sudoku_ack : uart_addr ? uart_ack : 0;
assign wb_dat_o = sudoku_addr ? sudoku_dat : uart_addr ? uart_dat : 0;

assign interrupt = interrupt_sudoku | interrupt_uart;

sudoku_puzzle_wb sudoku(
  .wb_clk_i(wb_clk_i), .wb_rst_i(wb_rst_i),
  .wb_adr_i(wb_adr_i), .wb_dat_i(wb_dat_i),
  .wb_sel_i(wb_sel_i), .wb_we_i(sudoku_addr & wb_we_i),
  .wb_cyc_i(sudoku_addr & wb_cyc_i), .wb_stb_i(sudoku_addr & wb_stb_i),
  .wb_ack_o(sudoku_ack), .wb_dat_o(sudoku_dat),

  .interrupt(interrupt_sudoku)
);

simpleuart_fifo_wb #(.BASE_ADR(32'h30800000)) uart (
  .wb_clk_i(wb_clk_i), .wb_rst_i(wb_rst_i),
  .wb_adr_i(wb_adr_i), .wb_dat_i(wb_dat_i),
  .wb_sel_i(wb_sel_i), .wb_we_i(uart_addr & wb_we_i),
  .wb_cyc_i(uart_addr & wb_cyc_i), .wb_stb_i(uart_addr & wb_stb_i),
  .wb_ack_o(uart_ack), .wb_dat_o(uart_dat),

  .uart_enabled(uart_enabled),
  .ser_tx(ser_tx), .ser_rx(ser_rx),

  .interrupt(interrupt_uart)
);

endmodule

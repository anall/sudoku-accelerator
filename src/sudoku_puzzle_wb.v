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
module sudoku_puzzle_wb #(
  parameter BASE_ADR = 32'h 3000_0000
) (
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

  output interrupt
);

wire [26:0] pzl_rdata_0;
wire [26:0] pzl_rdata_1;

wire [3:0] pzl_adr_cell = wb_adr_i[7:4];
wire       pzl_adr_type  = wb_adr_i[8];
wire       pzl_adr_xform = wb_adr_i[9];
wire       pzl_id = wb_adr_i[10];

wire [26:0] pzl_rdata =
  pzl_id ? pzl_rdata_1 : pzl_rdata_0;

wire wb_valid = wb_stb_i & wb_cyc_i;

wire addr_sel   = wb_valid & (wb_adr_i & 32'h FFFF_0000) == BASE_ADR & wb_adr_i[1:0] == 0;

// address decode for puzzles
//  54321098  76543210
// <0001?pxt><ccccaaww>

wire puzzles_sel = addr_sel & wb_adr_i[15:12] == 1;

wire [2:0] pzl_addr_third = (
  wb_adr_i[3:2] == 0 ? 3'b001 :
  wb_adr_i[3:2] == 1 ? 3'b010 :
  wb_adr_i[3:2] == 2 ? 3'b100 :
      0 );

wire [26:0] pzl_dat_o = pzl_rdata;

wire wb_sel_full = wb_sel_i == 4'b1111;

wire pzl_wb_requires_special = pzl_adr_xform & !wb_sel_full & wb_we_i;

wire [1:0] pzl_sel = {
  puzzles_sel & pzl_id,
  puzzles_sel & ! pzl_id
};

wire [8:0] xform_dat_t1h [2:0];

spw_to_one_hot xt1h0(.value(wb_dat_i[3:0]), .result(xform_dat_t1h[0]), .invert(pzl_adr_type));
spw_to_one_hot xt1h1(.value(wb_dat_i[11:8]), .result(xform_dat_t1h[1]), .invert(pzl_adr_type));
spw_to_one_hot xt1h2(.value(wb_dat_i[19:16]), .result(xform_dat_t1h[2]), .invert(pzl_adr_type));

wire [3:0] xform_dat_fxl [2:0];

spw_xlate xfx0(.value(pzl_dat_o[8:0]), .result(xform_dat_fxl[0]), .pop(pzl_adr_type));
spw_xlate xfx1(.value(pzl_dat_o[17:9]), .result(xform_dat_fxl[1]), .pop(pzl_adr_type));
spw_xlate xfx2(.value(pzl_dat_o[26:18]), .result(xform_dat_fxl[2]), .pop(pzl_adr_type));

wire addr_ctrl_status = addr_sel & wb_adr_i[15:0] == 'h0;
wire addr_ctrl_naked  = addr_sel & wb_adr_i[15:0] == 'h4;
wire addr_ctrl_ie     = addr_sel & wb_adr_i[15:0] == 'h8;

assign wb_dat_o =
  (puzzles_sel ?
    (pzl_adr_xform ? ( // we're reading the converted values, we want values to be converted from one hot, and valid to be popcnt
      {8'd0,4'd0,xform_dat_fxl[2],4'd0,xform_dat_fxl[1],4'd0,xform_dat_fxl[0]} )
    : pzl_dat_o) :
   addr_ctrl_status ? {
      8'd0,
      8'd0,
      4'd0,pzl_illegal[1],pzl_solved[1],pzl_stuck[1],pzl_busy[1],
      4'd0,pzl_illegal[0],pzl_solved[0],pzl_stuck[0],pzl_busy[0]
    } :
    addr_ctrl_naked ? {30'd0,pzl_allow_naked[1],pzl_allow_naked[0]} :
    addr_ctrl_ie    ? {16'd0,6'd0,pzl_interrupt,6'd0,pzl_ie_idle} :
      ~0);

//reg [26:0] pzl_wdata_i;
wire [26:0] pzl_wdata =
  pzl_adr_xform ?
      {xform_dat_t1h[2],xform_dat_t1h[1],xform_dat_t1h[0]}
    : wb_dat_i[26:0];

wire [4:0] pzl_addr = {pzl_adr_type,pzl_adr_cell};

wire pzl_we = puzzles_sel &
  pzl_adr_xform ? ( wb_we_i & (wb_sel_full) )
    : (wb_we_i & wb_sel_full);

reg [1:0] pzl_start;
reg [1:0] pzl_abort;

assign interrupt = pzl_interrupt != 0;
// consider start to be busy to avoid possible race condition if bus is fast at enabling interrupts
wire [1:0] pzl_interrupt = {~(pzl_busy[1]|pzl_start[1])&pzl_ie_idle[1],~(pzl_busy[0]|pzl_start[0])&pzl_ie_idle[0]};
reg [1:0] pzl_allow_naked;
reg [1:0] pzl_ie_idle;


always @(posedge wb_clk_i) begin
  if ( wb_rst_i ) begin
    pzl_start <= 0;
    pzl_abort <= 0;
    pzl_allow_naked <= 2'b11;

    pzl_ie_idle <= 0;
  end else if ( wb_we_i && addr_ctrl_ie && wb_ack_o && wb_sel_i[0] ) begin
    pzl_ie_idle <= wb_dat_i[1:0];
  end else if ( wb_we_i && addr_ctrl_status && wb_ack_o ) begin
    if ( wb_dat_i[0] && wb_sel_i[0] )
      pzl_start[0] <= 1;
    if ( wb_dat_i[1] && wb_sel_i[0] )
      pzl_abort[0] <= 1;
    if ( wb_dat_i[8] && wb_sel_i[1] )
      pzl_start[1] <= 1;
    if ( wb_dat_i[9] && wb_sel_i[1] )
      pzl_abort[1] <= 1;
  end else if ( wb_we_i && addr_ctrl_naked && wb_ack_o && wb_sel_i[0] ) begin
    if ( ~pzl_busy[0] )
      pzl_allow_naked[0] <= wb_dat_i[0];
    if ( ~pzl_busy[1] )
      pzl_allow_naked[1] <= wb_dat_i[1];
  end else begin
    if ( pzl_start[0] && pzl_busy[0] )
      pzl_start[0] <= 0;
    if ( pzl_start[1] && pzl_busy[1] )
      pzl_start[1] <= 0;
    if ( pzl_abort[0] && ~pzl_busy[0] )
      pzl_abort[0] <= 0;
    if ( pzl_abort[1] && ~pzl_busy[1] )
      pzl_abort[1] <= 0;
  end
end

wire [1:0] pzl_busy;
wire [1:0] pzl_solved;
wire [1:0] pzl_stuck;
wire [1:0] pzl_illegal;

wire wb_ack_o = (
    puzzles_sel
  | addr_ctrl_status
  | addr_ctrl_naked
  | addr_ctrl_ie
);

/*always @(posedge wb_clk_i) begin
  if ( wb_rst_i ) begin
    pzl_wdata_i <= 0;
    pzl_special_handled <= 0;
  end else begin
    if ( pzl_special_handled ) begin
      pzl_special_handled <= 0;
    end else if (pzl_wb_requires_special) begin
      if (pzl_adr_type == 0) begin
        pzl_wdata_i <= {
          (wb_sel_i[2] ? xform_dat_t1h[2] : pzl_dat_o[26:18]),
          (wb_sel_i[1] ? xform_dat_t1h[1] : pzl_dat_o[17:9]),
          (wb_sel_i[0] ? xform_dat_t1h[0] : pzl_dat_o[8:0])
        };
        pzl_special_handled <= 1;
      end else begin
        pzl_wdata_i[26:18] <= ~(wb_sel_i[2] ? xform_dat_t1h[2] : 0);
        pzl_wdata_i[17:9]  <= ~(wb_sel_i[1] ? xform_dat_t1h[1] : 0);
        pzl_wdata_i[8:0]   <= ~(wb_sel_i[0] ? xform_dat_t1h[0] : 0);
        pzl_special_handled <= 1;
      end
    end
  end
end*/

wire pzl_we_0 =
    ( pzl_we & pzl_sel[0] & wb_we_i & (wb_sel_full) );

wire pzl_we_1 =
    ( pzl_we & pzl_sel[1] & wb_we_i & (wb_sel_full) );

sudoku_puzzle puzzle0 (
  .clk(wb_clk_i), .reset(wb_rst_i),
  .wdata(pzl_wdata), .rdata(pzl_rdata_0),
  .address(pzl_addr), .we(pzl_we_0), .sel(pzl_addr_third),

  .start_solve(pzl_start[0]),
  .abort(pzl_abort[0]),
  .busy(pzl_busy[0]),
  .solved(pzl_solved[0]),
  .stuck(pzl_stuck[0]),
  .illegal(pzl_illegal[0]),

  .allow_naked(pzl_allow_naked[0])
);

sudoku_puzzle puzzle1 (
  .clk(wb_clk_i), .reset(wb_rst_i),
  .wdata(pzl_wdata), .rdata(pzl_rdata_1),
  .address(pzl_addr), .we(pzl_we_1), .sel(pzl_addr_third),

  .start_solve(pzl_start[1]),
  .abort(pzl_abort[1]),
  .busy(pzl_busy[1]),
  .solved(pzl_solved[1]),
  .stuck(pzl_stuck[1]),
  .illegal(pzl_illegal[1]),

  .allow_naked(pzl_allow_naked[1])
);

endmodule

module spw_to_one_hot (
  input [3:0] value,
  output [8:0] result,
  input invert
);

assign result = invert ? ~tmp : tmp;

reg [8:0] tmp;

always @(value) begin
  case (value)
    1: tmp = 9'b000000001;
    2: tmp = 9'b000000010;
    3: tmp = 9'b000000100;
    4: tmp = 9'b000001000;
    5: tmp = 9'b000010000;
    6: tmp = 9'b000100000;
    7: tmp = 9'b001000000;
    8: tmp = 9'b010000000;
    9: tmp = 9'b100000000;
    default: tmp = 0;
  endcase
end

endmodule

module spw_xlate (
  input [8:0] value,
  output [3:0] result,
  input pop
);

reg [3:0] result;

always @(value) begin
  if ( pop )
    result = value[0] + value[1] + value[2] + value[3] + value[4] + value[5] + value[6] + value[7] + value[8];
  else
    case (value)
      9'b000000000 : result = 0;
      9'b000000001 : result = 1;
      9'b000000010 : result = 2;
      9'b000000100 : result = 3;
      9'b000001000 : result = 4;
      9'b000010000 : result = 5;
      9'b000100000 : result = 6;
      9'b001000000 : result = 7;
      9'b010000000 : result = 8;
      9'b100000000 : result = 9;
      default: result = 4'b1111;
    endcase
end

endmodule


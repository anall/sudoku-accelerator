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
module sudoku_puzzle (
  input wire clk,
  input wire reset,

  // 9 cells wide (of 9 bits), able to transfer a full row of the puzzle at a time, or one full validity set
  // 8         7         6         5         4         3         2         1
  // 098765432109876543210987654321098765432109876543210987654321098765432109876543210
  // 123456789123456789123456789123456789123456789123456789123456789123456789123456789
  // 1        2        3        4        5        6        7        8        9
  input wire [80:0] wdata,
  output wire [80:0] rdata,

  // taaaa - 1 bit for type, 4 for address
  input wire [4:0] address,

  // low/med/high oe/we
  input wire [2:0] we,

  input wire start_solve,
  input wire abort,

  output wire busy,
  output wire solved,
  output reg stuck,
  output reg illegal,

  // switches to disable the naked stuff, in case there are bugs
  input wire allow_naked,
  input wire allow_naked_box,
  input wire allow_naked_col
);

wire [8:0] values [80:0];

reg [8:0] valid_row;       // used as a temporary
reg [8:0] valid_col [9]; // need the full set, as these will be set at the end
reg [8:0] valid_box [3]; // only need three of these

reg [3:0] count_row [9];
reg [6:0] count_col [9][9];
reg [6:0] count_box [3][9];

reg cell_addr_i = 0;
reg latch_singleton = 0;

localparam STATE_IDLE             =  0;
localparam STATE_LSINGLE          =  1;
localparam STATE_ELIM_ITER_ROW    =  2;
localparam STATE_ELIM_SAVE_ROW    =  3;
localparam STATE_ELIM_SAVE_BOX    =  4;
localparam STATE_ELIM_SAVE_COL    =  5;

localparam STATE_NAKED_ITER_ROW   =  6;
localparam STATE_NAKED_PROC_ROW   =  7;
localparam STATE_NAKED_SAVE_ROW   =  8;

localparam STATE_NAKED_ITER_BOX   =  9;
localparam STATE_NAKED_PROC_BOX   = 10;
localparam STATE_NAKED_SAVE_BOX   = 11;

localparam STATE_NAKED_PREP_COL   = 12;
localparam STATE_NAKED_ITER_COL   = 13;
localparam STATE_NAKED_PROC_COL   = 14;
localparam STATE_NAKED_SAVE_COL   = 15;
reg [3:0] state = STATE_IDLE;

assign busy = state != STATE_IDLE;

reg [8:0] row_en_decode;
always @(address) begin
  case (address[3:0])
    0: row_en_decode = 9'b000000001;
    1: row_en_decode = 9'b000000010;
    2: row_en_decode = 9'b000000100;
    3: row_en_decode = 9'b000001000;
    4: row_en_decode = 9'b000010000;
    5: row_en_decode = 9'b000100000;
    6: row_en_decode = 9'b001000000;
    7: row_en_decode = 9'b010000000;
    8: row_en_decode = 9'b100000000;
    default: row_en_decode = 0;
  endcase
end

wire [80:0] rdata_c =
  row_en_c[0] ? rdata_cell[0] :
  row_en_c[1] ? rdata_cell[1] :
  row_en_c[2] ? rdata_cell[2] :
  row_en_c[3] ? rdata_cell[3] :
  row_en_c[4] ? rdata_cell[4] :
  row_en_c[5] ? rdata_cell[5] :
  row_en_c[6] ? rdata_cell[6] :
  row_en_c[7] ? rdata_cell[7] :
  row_en_c[8] ? rdata_cell[8] : 0;

assign rdata = busy ? ~0 : rdata_c;
wire [80:0] wdata_c = busy ? wdata_i : wdata;

// internal versions of we, oe, and row_en, and data
reg [8:0] we_i;
reg [8:0] row_en_i;
reg [80:0] wdata_i;

// we, oe and row_en for cells (which will either be external or internal depending on busy state)
wire [8:0] we_c = busy ? we_i : {we[2],we[2],we[2],we[1],we[1],we[1],we[0],we[0],we[0]};
wire [8:0] row_en_c = busy ? row_en_i : row_en_decode;

wire is_singleton;
wire is_illegal;

wire cell_addr = busy ? cell_addr_i : address[4];

always @(posedge clk) begin
  if ( reset ) begin
    state <= STATE_IDLE;
    stuck <= 0;
    illegal <= 0;

    latch_singleton <= 0;
    we_i <= 0;
    cell_addr_i <= 0;

    wdata_i <= 0;
    row_en_i <= 0;
  end else if ( busy ) begin // busy means 'not STATE_IDLE'
    if ( solved || is_illegal || abort ) begin // abort if we ever hit solved or abort (stuck will exit when encountered)
      latch_singleton <= 0;
      we_i <= 0;
      cell_addr_i <= 0;
      row_en_i <= 0;
      stuck <= (is_illegal ? 1 : abort);
      illegal <= is_illegal;
      state <= STATE_IDLE;
    end else begin
      case ( state )
        STATE_LSINGLE : begin
          integer c;

          latch_singleton <= 0;
          if ( is_singleton || stuck ) begin // reuse "stuck" for first iteration
            stuck <= 0;
            row_en_i <= 1;
            cell_addr_i <= 0;

            for (c = 0; c < 9; c = c + 1) begin
              valid_col[c] <= 9'b111111111;
            end

            for (c = 0; c < 3; c = c + 1) begin
              valid_box[c] <= 9'b111111111;
            end

            state <= STATE_ELIM_ITER_ROW;
          end else begin
            integer c;
            integer d;
            stuck <= 1;
            row_en_i <= 1;
            latch_singleton <= 0;
            cell_addr_i <= 1;

            count_row[c] <= 0;
            for (d = 0; d < 9; d = d + 1) begin
              for (c = 0; c < 9; c = c + 1) begin
                count_col[d][c] <= 0;
              end
            end

            for (d = 0; d < 3; d = d + 1) begin
              for (c = 0; c < 9; c = c + 1) begin
                count_box[d][c] <= 0;
              end
            end

            if ( allow_naked ) begin
              state <= STATE_NAKED_ITER_ROW;
            end else begin
              stuck <= 1;
              state <= STATE_IDLE;
            end
          end
        end
        STATE_ELIM_ITER_ROW : begin
          integer c;
          integer box[3];

          end else if ( row_en_i[8] ) begin
            stuck <= 1;
            state <= STATE_LSINGLE;
          valid_row = 9'b111111111;
          for (c = 0; c < 9; c = c + 1) begin
            valid_col[c] <= valid_col[c] & ~rdata_c[9*(c+1)-1 -: 9];
            valid_box[c/3] = valid_box[c/3] & ~rdata_c[9*(c+1)-1 -: 9];
            valid_row = valid_row & ~rdata_c[9*(c+1)-1 -: 9];
          end

          for (c = 0; c < 9; c = c + 1) begin
            wdata_i[9*(c+1)-1 -: 9] <= valid_row;
          end

          we_i <= 9'b111111111;
          cell_addr_i <= 1;
          state <= STATE_ELIM_SAVE_ROW;
        end
        STATE_ELIM_SAVE_ROW : begin
          integer c;
          for (c = 0; c < 9; c = c + 1) begin
            wdata_i[9*(c+1)-1 -: 9] <= valid_box[c/3];
          end
          if ( row_en_i[2] || row_en_i[5] || row_en_i[8] ) begin
            row_en_i <= {row_en_i[8],row_en_i[8],row_en_i[8],row_en_i[5],row_en_i[5],row_en_i[5],row_en_i[2],row_en_i[2],row_en_i[2]};
            state <= STATE_ELIM_SAVE_BOX;
          end else begin
            /*latch_singleton <= 0;
            we_i <= 0;
            row_en_i <= 0;
            stuck <= 1;
            state <= STATE_IDLE;*/
            we_i <= 0;
            cell_addr_i <= 0;
            row_en_i <= {row_en_i[7:0],1'b0};
            state <= STATE_ELIM_ITER_ROW;
          end
        end
        STATE_ELIM_SAVE_BOX : begin
          integer c;
          if ( row_en_i[8] ) begin
            row_en_i <= 9'b111111111;
            for (c = 0; c < 9; c = c + 1) begin
              wdata_i[9*(c+1)-1 -: 9] <= valid_col[c];
            end
            state <= STATE_ELIM_SAVE_COL;
          end else begin
            we_i <= 0;
            cell_addr_i <= 0;
            row_en_i <= {2'b0,row_en_i[5],2'b0,row_en_i[2],3'b0}; // --x--y---

            for (c = 0; c < 3; c = c + 1) begin
              valid_box[c] <= 9'b111111111;
            end

            state <= STATE_ELIM_ITER_ROW;
          end
        end
        STATE_ELIM_SAVE_COL : begin
          we_i <= 0;
          cell_addr_i <= 0;
          latch_singleton <= 1;
          row_en_i <= 0;
          state <= STATE_LSINGLE;
        end
        STATE_NAKED_ITER_ROW : begin
          integer c;
          integer n;
          integer t [3];

          for (n = 0; n < 9; n = n + 1) begin
            t[0] = 0;
            t[1] = 0;
            t[2] = 0;
            for (c = 0; c < 9; c = c + 1) begin
              t[c/3] = t[c/3] + rdata_c[9*c+n];
              count_col[c][n] <= count_col[c][n] + rdata_c[9*c+n];
            end
            count_row[n] <= t[0] + t[1] + t[2];
            count_box[0][n] <= count_box[0][n] + t[0];
            count_box[1][n] <= count_box[1][n] + t[1];
            count_box[2][n] <= count_box[2][n] + t[2];
          end

          wdata_i <= rdata_c; // Stash this as we need the valid values
          cell_addr_i <= 0; // PROC_ROW needs the values
          state <= STATE_NAKED_PROC_ROW;
        end
        STATE_NAKED_PROC_ROW : begin
          integer c;
          integer t;
          for (c = 0; c < 9; c = c + 1) begin
            valid_row[c] = count_row[c] == 1;
          end

          if ( valid_row )
            stuck <= 0;
          for (c = 0; c < 9; c = c + 1) begin
            t = wdata_i[9*(c+1)-1 -: 9] & valid_row;
            wdata_i[9*(c+1)-1 -: 9] <= t ? t : rdata_c[9*(c+1)-1 -: 9];
            we_i[c] <= t ? 1 : 0;
          end
          state <= STATE_NAKED_SAVE_ROW;
        end
        STATE_NAKED_SAVE_ROW : begin
          integer c;

          we_i <= 0;
          if ( allow_naked_box && (row_en_i[2] || row_en_i[5] || row_en_i[8]) ) begin
            integer n;
            for (n = 0; n < 9; n = n + 1) begin
              valid_box[0][n] <= count_box[0][n] == 1;
              valid_box[1][n] <= count_box[1][n] == 1;
              valid_box[2][n] <= count_box[2][n] == 1;
            end

            row_en_i <= {2'd0,row_en_i[8],2'd0,row_en_i[5],2'd0,row_en_i[2]};
            cell_addr_i <= 1;
            state <= STATE_NAKED_ITER_BOX;
          end else if ( row_en_i[8] ) begin
            stuck <= 1;
            state <= STATE_LSINGLE;
          end else begin
            cell_addr_i <= 1;
            row_en_i <= {row_en_i[7:0],1'b0};
            state <= STATE_NAKED_ITER_ROW;
          end
        end
        STATE_NAKED_ITER_BOX: begin
          wdata_i <= rdata_c; // Stash this as we need the valid values
          cell_addr_i <= 0; // PROC_ROW needs the values
          state <= STATE_NAKED_PROC_BOX;
        end
        STATE_NAKED_PROC_BOX: begin
          integer c;
          integer t;

          if ( valid_box[0] || valid_box[1] || valid_box[2] )
            stuck <= 0;
          for (c = 0; c < 9; c = c + 1) begin
            t = wdata_i[9*(c+1)-1 -: 9] & valid_box[c/3];
            wdata_i[9*(c+1)-1 -: 9] <= t ? t : rdata_c[9*(c+1)-1 -: 9];
            we_i[c] <= t ? 1 : 0;
          end
          state <= STATE_NAKED_SAVE_BOX;
        end
        STATE_NAKED_SAVE_BOX: begin
          we_i <= 0;

          if ( row_en_i[8] && allow_naked_col ) begin
            integer n;
            for (n = 0; n < 9; n = n + 1) begin
              valid_col[0][n] <= count_col[0][n] == 1;
            end

            row_en_i <= 1;
            state <= STATE_NAKED_PREP_COL;
          end else if ( row_en_i[8] ) begin
            stuck <= 1;
            state <= STATE_LSINGLE;
          end else if ( row_en_i[2] || row_en_i[5] ) begin
            integer n;
            for (n = 0; n < 9; n = n + 1) begin
              count_box[0][n] <= 0;
              count_box[1][n] <= 0;
              count_box[2][n] <= 0;
            end

            cell_addr_i <= 1;
            row_en_i <= {row_en_i[7:0],1'b0};
            state <= STATE_NAKED_ITER_ROW;
          end else begin
            cell_addr_i <= 1;
            row_en_i <= {row_en_i[7:0],1'b0};
            state <= STATE_NAKED_ITER_BOX;
          end
        end
        STATE_NAKED_PREP_COL: begin
          integer n;
          for (n = 0; n < 9; n = n + 1) begin
            valid_col[row_en_i][n] <= count_col[row_en_i][n] == 1;
          end
          if ( valid_col[row_en_i-1] )
            stuck <= 0;
          if ( row_en_i == 8 ) begin
            row_en_i <= 1;
            cell_addr_i <= 1;
            state <= STATE_NAKED_ITER_COL;
          end else begin
            row_en_i <= row_en_i+1;
          end
        end
        STATE_NAKED_ITER_COL: begin
          if ( valid_col[8] )
            stuck <= 0;

          wdata_i <= rdata_c; // Stash this as we need the valid values
          cell_addr_i <= 0;
          state <= STATE_NAKED_PROC_COL;
        end
        STATE_NAKED_PROC_COL: begin
          integer c;
          integer t;

          for (c = 0; c < 9; c = c + 1) begin
            t = wdata_i[9*(c+1)-1 -: 9] & valid_col[c];
            wdata_i[9*(c+1)-1 -: 9] <= t ? t : ~0; // rdata_c[9*(c+1)-1 -: 9];
            we_i[c] <= t ? 1 : 0;
          end
          state <= STATE_NAKED_SAVE_COL;
        end
        STATE_NAKED_SAVE_COL: begin
          we_i <= 0;
          
          if ( row_en_i[8] ) begin
            stuck <= 1;
            state <= STATE_LSINGLE;
          end else begin
            cell_addr_i <= 1;
            row_en_i <= {row_en_i[7:0],1'b0};
            state <= STATE_NAKED_ITER_COL;
          end
        end
      endcase
    end
  end else if ( start_solve && ~solved ) begin
    latch_singleton <= 1;
    we_i <= 0;
    cell_addr_i <= 0;
    stuck <= 1;
    illegal <= 0;
    state <= STATE_LSINGLE;
  end
end

// -----GENERATED CODE FOLLOWS-----
// Following generated using tools/generate_cells.pl
wire [80:0] cell_singleton;
assign is_singleton = 0
      | cell_singleton[80] | cell_singleton[79] | cell_singleton[78] | cell_singleton[77] | cell_singleton[76] | cell_singleton[75] | cell_singleton[74] | cell_singleton[73] | cell_singleton[72]
      | cell_singleton[71] | cell_singleton[70] | cell_singleton[69] | cell_singleton[68] | cell_singleton[67] | cell_singleton[66] | cell_singleton[65] | cell_singleton[64] | cell_singleton[63]
      | cell_singleton[62] | cell_singleton[61] | cell_singleton[60] | cell_singleton[59] | cell_singleton[58] | cell_singleton[57] | cell_singleton[56] | cell_singleton[55] | cell_singleton[54]
      | cell_singleton[53] | cell_singleton[52] | cell_singleton[51] | cell_singleton[50] | cell_singleton[49] | cell_singleton[48] | cell_singleton[47] | cell_singleton[46] | cell_singleton[45]
      | cell_singleton[44] | cell_singleton[43] | cell_singleton[42] | cell_singleton[41] | cell_singleton[40] | cell_singleton[39] | cell_singleton[38] | cell_singleton[37] | cell_singleton[36]
      | cell_singleton[35] | cell_singleton[34] | cell_singleton[33] | cell_singleton[32] | cell_singleton[31] | cell_singleton[30] | cell_singleton[29] | cell_singleton[28] | cell_singleton[27]
      | cell_singleton[26] | cell_singleton[25] | cell_singleton[24] | cell_singleton[23] | cell_singleton[22] | cell_singleton[21] | cell_singleton[20] | cell_singleton[19] | cell_singleton[18]
      | cell_singleton[17] | cell_singleton[16] | cell_singleton[15] | cell_singleton[14] | cell_singleton[13] | cell_singleton[12] | cell_singleton[11] | cell_singleton[10] | cell_singleton[9]
      | cell_singleton[8] | cell_singleton[7] | cell_singleton[6] | cell_singleton[5] | cell_singleton[4] | cell_singleton[3] | cell_singleton[2] | cell_singleton[1] | cell_singleton[0];
wire [80:0] cell_illegal;
assign is_illegal = 0
      | cell_illegal[80] | cell_illegal[79] | cell_illegal[78] | cell_illegal[77] | cell_illegal[76] | cell_illegal[75] | cell_illegal[74] | cell_illegal[73] | cell_illegal[72]
      | cell_illegal[71] | cell_illegal[70] | cell_illegal[69] | cell_illegal[68] | cell_illegal[67] | cell_illegal[66] | cell_illegal[65] | cell_illegal[64] | cell_illegal[63]
      | cell_illegal[62] | cell_illegal[61] | cell_illegal[60] | cell_illegal[59] | cell_illegal[58] | cell_illegal[57] | cell_illegal[56] | cell_illegal[55] | cell_illegal[54]
      | cell_illegal[53] | cell_illegal[52] | cell_illegal[51] | cell_illegal[50] | cell_illegal[49] | cell_illegal[48] | cell_illegal[47] | cell_illegal[46] | cell_illegal[45]
      | cell_illegal[44] | cell_illegal[43] | cell_illegal[42] | cell_illegal[41] | cell_illegal[40] | cell_illegal[39] | cell_illegal[38] | cell_illegal[37] | cell_illegal[36]
      | cell_illegal[35] | cell_illegal[34] | cell_illegal[33] | cell_illegal[32] | cell_illegal[31] | cell_illegal[30] | cell_illegal[29] | cell_illegal[28] | cell_illegal[27]
      | cell_illegal[26] | cell_illegal[25] | cell_illegal[24] | cell_illegal[23] | cell_illegal[22] | cell_illegal[21] | cell_illegal[20] | cell_illegal[19] | cell_illegal[18]
      | cell_illegal[17] | cell_illegal[16] | cell_illegal[15] | cell_illegal[14] | cell_illegal[13] | cell_illegal[12] | cell_illegal[11] | cell_illegal[10] | cell_illegal[9]
      | cell_illegal[8] | cell_illegal[7] | cell_illegal[6] | cell_illegal[5] | cell_illegal[4] | cell_illegal[3] | cell_illegal[2] | cell_illegal[1] | cell_illegal[0];
wire [80:0] cell_solved;
assign solved = 1
      & cell_solved[80] & cell_solved[79] & cell_solved[78] & cell_solved[77] & cell_solved[76] & cell_solved[75] & cell_solved[74] & cell_solved[73] & cell_solved[72]
      & cell_solved[71] & cell_solved[70] & cell_solved[69] & cell_solved[68] & cell_solved[67] & cell_solved[66] & cell_solved[65] & cell_solved[64] & cell_solved[63]
      & cell_solved[62] & cell_solved[61] & cell_solved[60] & cell_solved[59] & cell_solved[58] & cell_solved[57] & cell_solved[56] & cell_solved[55] & cell_solved[54]
      & cell_solved[53] & cell_solved[52] & cell_solved[51] & cell_solved[50] & cell_solved[49] & cell_solved[48] & cell_solved[47] & cell_solved[46] & cell_solved[45]
      & cell_solved[44] & cell_solved[43] & cell_solved[42] & cell_solved[41] & cell_solved[40] & cell_solved[39] & cell_solved[38] & cell_solved[37] & cell_solved[36]
      & cell_solved[35] & cell_solved[34] & cell_solved[33] & cell_solved[32] & cell_solved[31] & cell_solved[30] & cell_solved[29] & cell_solved[28] & cell_solved[27]
      & cell_solved[26] & cell_solved[25] & cell_solved[24] & cell_solved[23] & cell_solved[22] & cell_solved[21] & cell_solved[20] & cell_solved[19] & cell_solved[18]
      & cell_solved[17] & cell_solved[16] & cell_solved[15] & cell_solved[14] & cell_solved[13] & cell_solved[12] & cell_solved[11] & cell_solved[10] & cell_solved[9]
      & cell_solved[8] & cell_solved[7] & cell_solved[6] & cell_solved[5] & cell_solved[4] & cell_solved[3] & cell_solved[2] & cell_solved[1] & cell_solved[0];
wire [80:0] rdata_cell [0:8];
sudoku_cell cell00( .clk(clk), .reset(reset),
  .rdata(rdata_cell[0][8:0]), .wdata(wdata_c[8:0]),
  .address(cell_addr), .we(row_en_c[0] & we_c[0]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[0]), .is_illegal(cell_illegal[0]), .solved(cell_solved[0]) );
sudoku_cell cell01( .clk(clk), .reset(reset),
  .rdata(rdata_cell[0][17:9]), .wdata(wdata_c[17:9]),
  .address(cell_addr), .we(row_en_c[0] & we_c[1]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[1]), .is_illegal(cell_illegal[1]), .solved(cell_solved[1]) );
sudoku_cell cell02( .clk(clk), .reset(reset),
  .rdata(rdata_cell[0][26:18]), .wdata(wdata_c[26:18]),
  .address(cell_addr), .we(row_en_c[0] & we_c[2]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[2]), .is_illegal(cell_illegal[2]), .solved(cell_solved[2]) );
sudoku_cell cell03( .clk(clk), .reset(reset),
  .rdata(rdata_cell[0][35:27]), .wdata(wdata_c[35:27]),
  .address(cell_addr), .we(row_en_c[0] & we_c[3]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[3]), .is_illegal(cell_illegal[3]), .solved(cell_solved[3]) );
sudoku_cell cell04( .clk(clk), .reset(reset),
  .rdata(rdata_cell[0][44:36]), .wdata(wdata_c[44:36]),
  .address(cell_addr), .we(row_en_c[0] & we_c[4]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[4]), .is_illegal(cell_illegal[4]), .solved(cell_solved[4]) );
sudoku_cell cell05( .clk(clk), .reset(reset),
  .rdata(rdata_cell[0][53:45]), .wdata(wdata_c[53:45]),
  .address(cell_addr), .we(row_en_c[0] & we_c[5]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[5]), .is_illegal(cell_illegal[5]), .solved(cell_solved[5]) );
sudoku_cell cell06( .clk(clk), .reset(reset),
  .rdata(rdata_cell[0][62:54]), .wdata(wdata_c[62:54]),
  .address(cell_addr), .we(row_en_c[0] & we_c[6]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[6]), .is_illegal(cell_illegal[6]), .solved(cell_solved[6]) );
sudoku_cell cell07( .clk(clk), .reset(reset),
  .rdata(rdata_cell[0][71:63]), .wdata(wdata_c[71:63]),
  .address(cell_addr), .we(row_en_c[0] & we_c[7]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[7]), .is_illegal(cell_illegal[7]), .solved(cell_solved[7]) );
sudoku_cell cell08( .clk(clk), .reset(reset),
  .rdata(rdata_cell[0][80:72]), .wdata(wdata_c[80:72]),
  .address(cell_addr), .we(row_en_c[0] & we_c[8]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[8]), .is_illegal(cell_illegal[8]), .solved(cell_solved[8]) );
sudoku_cell cell10( .clk(clk), .reset(reset),
  .rdata(rdata_cell[1][8:0]), .wdata(wdata_c[8:0]),
  .address(cell_addr), .we(row_en_c[1] & we_c[0]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[9]), .is_illegal(cell_illegal[9]), .solved(cell_solved[9]) );
sudoku_cell cell11( .clk(clk), .reset(reset),
  .rdata(rdata_cell[1][17:9]), .wdata(wdata_c[17:9]),
  .address(cell_addr), .we(row_en_c[1] & we_c[1]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[10]), .is_illegal(cell_illegal[10]), .solved(cell_solved[10]) );
sudoku_cell cell12( .clk(clk), .reset(reset),
  .rdata(rdata_cell[1][26:18]), .wdata(wdata_c[26:18]),
  .address(cell_addr), .we(row_en_c[1] & we_c[2]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[11]), .is_illegal(cell_illegal[11]), .solved(cell_solved[11]) );
sudoku_cell cell13( .clk(clk), .reset(reset),
  .rdata(rdata_cell[1][35:27]), .wdata(wdata_c[35:27]),
  .address(cell_addr), .we(row_en_c[1] & we_c[3]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[12]), .is_illegal(cell_illegal[12]), .solved(cell_solved[12]) );
sudoku_cell cell14( .clk(clk), .reset(reset),
  .rdata(rdata_cell[1][44:36]), .wdata(wdata_c[44:36]),
  .address(cell_addr), .we(row_en_c[1] & we_c[4]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[13]), .is_illegal(cell_illegal[13]), .solved(cell_solved[13]) );
sudoku_cell cell15( .clk(clk), .reset(reset),
  .rdata(rdata_cell[1][53:45]), .wdata(wdata_c[53:45]),
  .address(cell_addr), .we(row_en_c[1] & we_c[5]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[14]), .is_illegal(cell_illegal[14]), .solved(cell_solved[14]) );
sudoku_cell cell16( .clk(clk), .reset(reset),
  .rdata(rdata_cell[1][62:54]), .wdata(wdata_c[62:54]),
  .address(cell_addr), .we(row_en_c[1] & we_c[6]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[15]), .is_illegal(cell_illegal[15]), .solved(cell_solved[15]) );
sudoku_cell cell17( .clk(clk), .reset(reset),
  .rdata(rdata_cell[1][71:63]), .wdata(wdata_c[71:63]),
  .address(cell_addr), .we(row_en_c[1] & we_c[7]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[16]), .is_illegal(cell_illegal[16]), .solved(cell_solved[16]) );
sudoku_cell cell18( .clk(clk), .reset(reset),
  .rdata(rdata_cell[1][80:72]), .wdata(wdata_c[80:72]),
  .address(cell_addr), .we(row_en_c[1] & we_c[8]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[17]), .is_illegal(cell_illegal[17]), .solved(cell_solved[17]) );
sudoku_cell cell20( .clk(clk), .reset(reset),
  .rdata(rdata_cell[2][8:0]), .wdata(wdata_c[8:0]),
  .address(cell_addr), .we(row_en_c[2] & we_c[0]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[18]), .is_illegal(cell_illegal[18]), .solved(cell_solved[18]) );
sudoku_cell cell21( .clk(clk), .reset(reset),
  .rdata(rdata_cell[2][17:9]), .wdata(wdata_c[17:9]),
  .address(cell_addr), .we(row_en_c[2] & we_c[1]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[19]), .is_illegal(cell_illegal[19]), .solved(cell_solved[19]) );
sudoku_cell cell22( .clk(clk), .reset(reset),
  .rdata(rdata_cell[2][26:18]), .wdata(wdata_c[26:18]),
  .address(cell_addr), .we(row_en_c[2] & we_c[2]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[20]), .is_illegal(cell_illegal[20]), .solved(cell_solved[20]) );
sudoku_cell cell23( .clk(clk), .reset(reset),
  .rdata(rdata_cell[2][35:27]), .wdata(wdata_c[35:27]),
  .address(cell_addr), .we(row_en_c[2] & we_c[3]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[21]), .is_illegal(cell_illegal[21]), .solved(cell_solved[21]) );
sudoku_cell cell24( .clk(clk), .reset(reset),
  .rdata(rdata_cell[2][44:36]), .wdata(wdata_c[44:36]),
  .address(cell_addr), .we(row_en_c[2] & we_c[4]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[22]), .is_illegal(cell_illegal[22]), .solved(cell_solved[22]) );
sudoku_cell cell25( .clk(clk), .reset(reset),
  .rdata(rdata_cell[2][53:45]), .wdata(wdata_c[53:45]),
  .address(cell_addr), .we(row_en_c[2] & we_c[5]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[23]), .is_illegal(cell_illegal[23]), .solved(cell_solved[23]) );
sudoku_cell cell26( .clk(clk), .reset(reset),
  .rdata(rdata_cell[2][62:54]), .wdata(wdata_c[62:54]),
  .address(cell_addr), .we(row_en_c[2] & we_c[6]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[24]), .is_illegal(cell_illegal[24]), .solved(cell_solved[24]) );
sudoku_cell cell27( .clk(clk), .reset(reset),
  .rdata(rdata_cell[2][71:63]), .wdata(wdata_c[71:63]),
  .address(cell_addr), .we(row_en_c[2] & we_c[7]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[25]), .is_illegal(cell_illegal[25]), .solved(cell_solved[25]) );
sudoku_cell cell28( .clk(clk), .reset(reset),
  .rdata(rdata_cell[2][80:72]), .wdata(wdata_c[80:72]),
  .address(cell_addr), .we(row_en_c[2] & we_c[8]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[26]), .is_illegal(cell_illegal[26]), .solved(cell_solved[26]) );
sudoku_cell cell30( .clk(clk), .reset(reset),
  .rdata(rdata_cell[3][8:0]), .wdata(wdata_c[8:0]),
  .address(cell_addr), .we(row_en_c[3] & we_c[0]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[27]), .is_illegal(cell_illegal[27]), .solved(cell_solved[27]) );
sudoku_cell cell31( .clk(clk), .reset(reset),
  .rdata(rdata_cell[3][17:9]), .wdata(wdata_c[17:9]),
  .address(cell_addr), .we(row_en_c[3] & we_c[1]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[28]), .is_illegal(cell_illegal[28]), .solved(cell_solved[28]) );
sudoku_cell cell32( .clk(clk), .reset(reset),
  .rdata(rdata_cell[3][26:18]), .wdata(wdata_c[26:18]),
  .address(cell_addr), .we(row_en_c[3] & we_c[2]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[29]), .is_illegal(cell_illegal[29]), .solved(cell_solved[29]) );
sudoku_cell cell33( .clk(clk), .reset(reset),
  .rdata(rdata_cell[3][35:27]), .wdata(wdata_c[35:27]),
  .address(cell_addr), .we(row_en_c[3] & we_c[3]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[30]), .is_illegal(cell_illegal[30]), .solved(cell_solved[30]) );
sudoku_cell cell34( .clk(clk), .reset(reset),
  .rdata(rdata_cell[3][44:36]), .wdata(wdata_c[44:36]),
  .address(cell_addr), .we(row_en_c[3] & we_c[4]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[31]), .is_illegal(cell_illegal[31]), .solved(cell_solved[31]) );
sudoku_cell cell35( .clk(clk), .reset(reset),
  .rdata(rdata_cell[3][53:45]), .wdata(wdata_c[53:45]),
  .address(cell_addr), .we(row_en_c[3] & we_c[5]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[32]), .is_illegal(cell_illegal[32]), .solved(cell_solved[32]) );
sudoku_cell cell36( .clk(clk), .reset(reset),
  .rdata(rdata_cell[3][62:54]), .wdata(wdata_c[62:54]),
  .address(cell_addr), .we(row_en_c[3] & we_c[6]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[33]), .is_illegal(cell_illegal[33]), .solved(cell_solved[33]) );
sudoku_cell cell37( .clk(clk), .reset(reset),
  .rdata(rdata_cell[3][71:63]), .wdata(wdata_c[71:63]),
  .address(cell_addr), .we(row_en_c[3] & we_c[7]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[34]), .is_illegal(cell_illegal[34]), .solved(cell_solved[34]) );
sudoku_cell cell38( .clk(clk), .reset(reset),
  .rdata(rdata_cell[3][80:72]), .wdata(wdata_c[80:72]),
  .address(cell_addr), .we(row_en_c[3] & we_c[8]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[35]), .is_illegal(cell_illegal[35]), .solved(cell_solved[35]) );
sudoku_cell cell40( .clk(clk), .reset(reset),
  .rdata(rdata_cell[4][8:0]), .wdata(wdata_c[8:0]),
  .address(cell_addr), .we(row_en_c[4] & we_c[0]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[36]), .is_illegal(cell_illegal[36]), .solved(cell_solved[36]) );
sudoku_cell cell41( .clk(clk), .reset(reset),
  .rdata(rdata_cell[4][17:9]), .wdata(wdata_c[17:9]),
  .address(cell_addr), .we(row_en_c[4] & we_c[1]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[37]), .is_illegal(cell_illegal[37]), .solved(cell_solved[37]) );
sudoku_cell cell42( .clk(clk), .reset(reset),
  .rdata(rdata_cell[4][26:18]), .wdata(wdata_c[26:18]),
  .address(cell_addr), .we(row_en_c[4] & we_c[2]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[38]), .is_illegal(cell_illegal[38]), .solved(cell_solved[38]) );
sudoku_cell cell43( .clk(clk), .reset(reset),
  .rdata(rdata_cell[4][35:27]), .wdata(wdata_c[35:27]),
  .address(cell_addr), .we(row_en_c[4] & we_c[3]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[39]), .is_illegal(cell_illegal[39]), .solved(cell_solved[39]) );
sudoku_cell cell44( .clk(clk), .reset(reset),
  .rdata(rdata_cell[4][44:36]), .wdata(wdata_c[44:36]),
  .address(cell_addr), .we(row_en_c[4] & we_c[4]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[40]), .is_illegal(cell_illegal[40]), .solved(cell_solved[40]) );
sudoku_cell cell45( .clk(clk), .reset(reset),
  .rdata(rdata_cell[4][53:45]), .wdata(wdata_c[53:45]),
  .address(cell_addr), .we(row_en_c[4] & we_c[5]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[41]), .is_illegal(cell_illegal[41]), .solved(cell_solved[41]) );
sudoku_cell cell46( .clk(clk), .reset(reset),
  .rdata(rdata_cell[4][62:54]), .wdata(wdata_c[62:54]),
  .address(cell_addr), .we(row_en_c[4] & we_c[6]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[42]), .is_illegal(cell_illegal[42]), .solved(cell_solved[42]) );
sudoku_cell cell47( .clk(clk), .reset(reset),
  .rdata(rdata_cell[4][71:63]), .wdata(wdata_c[71:63]),
  .address(cell_addr), .we(row_en_c[4] & we_c[7]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[43]), .is_illegal(cell_illegal[43]), .solved(cell_solved[43]) );
sudoku_cell cell48( .clk(clk), .reset(reset),
  .rdata(rdata_cell[4][80:72]), .wdata(wdata_c[80:72]),
  .address(cell_addr), .we(row_en_c[4] & we_c[8]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[44]), .is_illegal(cell_illegal[44]), .solved(cell_solved[44]) );
sudoku_cell cell50( .clk(clk), .reset(reset),
  .rdata(rdata_cell[5][8:0]), .wdata(wdata_c[8:0]),
  .address(cell_addr), .we(row_en_c[5] & we_c[0]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[45]), .is_illegal(cell_illegal[45]), .solved(cell_solved[45]) );
sudoku_cell cell51( .clk(clk), .reset(reset),
  .rdata(rdata_cell[5][17:9]), .wdata(wdata_c[17:9]),
  .address(cell_addr), .we(row_en_c[5] & we_c[1]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[46]), .is_illegal(cell_illegal[46]), .solved(cell_solved[46]) );
sudoku_cell cell52( .clk(clk), .reset(reset),
  .rdata(rdata_cell[5][26:18]), .wdata(wdata_c[26:18]),
  .address(cell_addr), .we(row_en_c[5] & we_c[2]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[47]), .is_illegal(cell_illegal[47]), .solved(cell_solved[47]) );
sudoku_cell cell53( .clk(clk), .reset(reset),
  .rdata(rdata_cell[5][35:27]), .wdata(wdata_c[35:27]),
  .address(cell_addr), .we(row_en_c[5] & we_c[3]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[48]), .is_illegal(cell_illegal[48]), .solved(cell_solved[48]) );
sudoku_cell cell54( .clk(clk), .reset(reset),
  .rdata(rdata_cell[5][44:36]), .wdata(wdata_c[44:36]),
  .address(cell_addr), .we(row_en_c[5] & we_c[4]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[49]), .is_illegal(cell_illegal[49]), .solved(cell_solved[49]) );
sudoku_cell cell55( .clk(clk), .reset(reset),
  .rdata(rdata_cell[5][53:45]), .wdata(wdata_c[53:45]),
  .address(cell_addr), .we(row_en_c[5] & we_c[5]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[50]), .is_illegal(cell_illegal[50]), .solved(cell_solved[50]) );
sudoku_cell cell56( .clk(clk), .reset(reset),
  .rdata(rdata_cell[5][62:54]), .wdata(wdata_c[62:54]),
  .address(cell_addr), .we(row_en_c[5] & we_c[6]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[51]), .is_illegal(cell_illegal[51]), .solved(cell_solved[51]) );
sudoku_cell cell57( .clk(clk), .reset(reset),
  .rdata(rdata_cell[5][71:63]), .wdata(wdata_c[71:63]),
  .address(cell_addr), .we(row_en_c[5] & we_c[7]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[52]), .is_illegal(cell_illegal[52]), .solved(cell_solved[52]) );
sudoku_cell cell58( .clk(clk), .reset(reset),
  .rdata(rdata_cell[5][80:72]), .wdata(wdata_c[80:72]),
  .address(cell_addr), .we(row_en_c[5] & we_c[8]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[53]), .is_illegal(cell_illegal[53]), .solved(cell_solved[53]) );
sudoku_cell cell60( .clk(clk), .reset(reset),
  .rdata(rdata_cell[6][8:0]), .wdata(wdata_c[8:0]),
  .address(cell_addr), .we(row_en_c[6] & we_c[0]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[54]), .is_illegal(cell_illegal[54]), .solved(cell_solved[54]) );
sudoku_cell cell61( .clk(clk), .reset(reset),
  .rdata(rdata_cell[6][17:9]), .wdata(wdata_c[17:9]),
  .address(cell_addr), .we(row_en_c[6] & we_c[1]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[55]), .is_illegal(cell_illegal[55]), .solved(cell_solved[55]) );
sudoku_cell cell62( .clk(clk), .reset(reset),
  .rdata(rdata_cell[6][26:18]), .wdata(wdata_c[26:18]),
  .address(cell_addr), .we(row_en_c[6] & we_c[2]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[56]), .is_illegal(cell_illegal[56]), .solved(cell_solved[56]) );
sudoku_cell cell63( .clk(clk), .reset(reset),
  .rdata(rdata_cell[6][35:27]), .wdata(wdata_c[35:27]),
  .address(cell_addr), .we(row_en_c[6] & we_c[3]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[57]), .is_illegal(cell_illegal[57]), .solved(cell_solved[57]) );
sudoku_cell cell64( .clk(clk), .reset(reset),
  .rdata(rdata_cell[6][44:36]), .wdata(wdata_c[44:36]),
  .address(cell_addr), .we(row_en_c[6] & we_c[4]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[58]), .is_illegal(cell_illegal[58]), .solved(cell_solved[58]) );
sudoku_cell cell65( .clk(clk), .reset(reset),
  .rdata(rdata_cell[6][53:45]), .wdata(wdata_c[53:45]),
  .address(cell_addr), .we(row_en_c[6] & we_c[5]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[59]), .is_illegal(cell_illegal[59]), .solved(cell_solved[59]) );
sudoku_cell cell66( .clk(clk), .reset(reset),
  .rdata(rdata_cell[6][62:54]), .wdata(wdata_c[62:54]),
  .address(cell_addr), .we(row_en_c[6] & we_c[6]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[60]), .is_illegal(cell_illegal[60]), .solved(cell_solved[60]) );
sudoku_cell cell67( .clk(clk), .reset(reset),
  .rdata(rdata_cell[6][71:63]), .wdata(wdata_c[71:63]),
  .address(cell_addr), .we(row_en_c[6] & we_c[7]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[61]), .is_illegal(cell_illegal[61]), .solved(cell_solved[61]) );
sudoku_cell cell68( .clk(clk), .reset(reset),
  .rdata(rdata_cell[6][80:72]), .wdata(wdata_c[80:72]),
  .address(cell_addr), .we(row_en_c[6] & we_c[8]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[62]), .is_illegal(cell_illegal[62]), .solved(cell_solved[62]) );
sudoku_cell cell70( .clk(clk), .reset(reset),
  .rdata(rdata_cell[7][8:0]), .wdata(wdata_c[8:0]),
  .address(cell_addr), .we(row_en_c[7] & we_c[0]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[63]), .is_illegal(cell_illegal[63]), .solved(cell_solved[63]) );
sudoku_cell cell71( .clk(clk), .reset(reset),
  .rdata(rdata_cell[7][17:9]), .wdata(wdata_c[17:9]),
  .address(cell_addr), .we(row_en_c[7] & we_c[1]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[64]), .is_illegal(cell_illegal[64]), .solved(cell_solved[64]) );
sudoku_cell cell72( .clk(clk), .reset(reset),
  .rdata(rdata_cell[7][26:18]), .wdata(wdata_c[26:18]),
  .address(cell_addr), .we(row_en_c[7] & we_c[2]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[65]), .is_illegal(cell_illegal[65]), .solved(cell_solved[65]) );
sudoku_cell cell73( .clk(clk), .reset(reset),
  .rdata(rdata_cell[7][35:27]), .wdata(wdata_c[35:27]),
  .address(cell_addr), .we(row_en_c[7] & we_c[3]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[66]), .is_illegal(cell_illegal[66]), .solved(cell_solved[66]) );
sudoku_cell cell74( .clk(clk), .reset(reset),
  .rdata(rdata_cell[7][44:36]), .wdata(wdata_c[44:36]),
  .address(cell_addr), .we(row_en_c[7] & we_c[4]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[67]), .is_illegal(cell_illegal[67]), .solved(cell_solved[67]) );
sudoku_cell cell75( .clk(clk), .reset(reset),
  .rdata(rdata_cell[7][53:45]), .wdata(wdata_c[53:45]),
  .address(cell_addr), .we(row_en_c[7] & we_c[5]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[68]), .is_illegal(cell_illegal[68]), .solved(cell_solved[68]) );
sudoku_cell cell76( .clk(clk), .reset(reset),
  .rdata(rdata_cell[7][62:54]), .wdata(wdata_c[62:54]),
  .address(cell_addr), .we(row_en_c[7] & we_c[6]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[69]), .is_illegal(cell_illegal[69]), .solved(cell_solved[69]) );
sudoku_cell cell77( .clk(clk), .reset(reset),
  .rdata(rdata_cell[7][71:63]), .wdata(wdata_c[71:63]),
  .address(cell_addr), .we(row_en_c[7] & we_c[7]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[70]), .is_illegal(cell_illegal[70]), .solved(cell_solved[70]) );
sudoku_cell cell78( .clk(clk), .reset(reset),
  .rdata(rdata_cell[7][80:72]), .wdata(wdata_c[80:72]),
  .address(cell_addr), .we(row_en_c[7] & we_c[8]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[71]), .is_illegal(cell_illegal[71]), .solved(cell_solved[71]) );
sudoku_cell cell80( .clk(clk), .reset(reset),
  .rdata(rdata_cell[8][8:0]), .wdata(wdata_c[8:0]),
  .address(cell_addr), .we(row_en_c[8] & we_c[0]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[72]), .is_illegal(cell_illegal[72]), .solved(cell_solved[72]) );
sudoku_cell cell81( .clk(clk), .reset(reset),
  .rdata(rdata_cell[8][17:9]), .wdata(wdata_c[17:9]),
  .address(cell_addr), .we(row_en_c[8] & we_c[1]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[73]), .is_illegal(cell_illegal[73]), .solved(cell_solved[73]) );
sudoku_cell cell82( .clk(clk), .reset(reset),
  .rdata(rdata_cell[8][26:18]), .wdata(wdata_c[26:18]),
  .address(cell_addr), .we(row_en_c[8] & we_c[2]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[74]), .is_illegal(cell_illegal[74]), .solved(cell_solved[74]) );
sudoku_cell cell83( .clk(clk), .reset(reset),
  .rdata(rdata_cell[8][35:27]), .wdata(wdata_c[35:27]),
  .address(cell_addr), .we(row_en_c[8] & we_c[3]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[75]), .is_illegal(cell_illegal[75]), .solved(cell_solved[75]) );
sudoku_cell cell84( .clk(clk), .reset(reset),
  .rdata(rdata_cell[8][44:36]), .wdata(wdata_c[44:36]),
  .address(cell_addr), .we(row_en_c[8] & we_c[4]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[76]), .is_illegal(cell_illegal[76]), .solved(cell_solved[76]) );
sudoku_cell cell85( .clk(clk), .reset(reset),
  .rdata(rdata_cell[8][53:45]), .wdata(wdata_c[53:45]),
  .address(cell_addr), .we(row_en_c[8] & we_c[5]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[77]), .is_illegal(cell_illegal[77]), .solved(cell_solved[77]) );
sudoku_cell cell86( .clk(clk), .reset(reset),
  .rdata(rdata_cell[8][62:54]), .wdata(wdata_c[62:54]),
  .address(cell_addr), .we(row_en_c[8] & we_c[6]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[78]), .is_illegal(cell_illegal[78]), .solved(cell_solved[78]) );
sudoku_cell cell87( .clk(clk), .reset(reset),
  .rdata(rdata_cell[8][71:63]), .wdata(wdata_c[71:63]),
  .address(cell_addr), .we(row_en_c[8] & we_c[7]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[79]), .is_illegal(cell_illegal[79]), .solved(cell_solved[79]) );
sudoku_cell cell88( .clk(clk), .reset(reset),
  .rdata(rdata_cell[8][80:72]), .wdata(wdata_c[80:72]),
  .address(cell_addr), .we(row_en_c[8] & we_c[8]),
  .latch_singleton(latch_singleton),
  .is_singleton(cell_singleton[80]), .is_illegal(cell_illegal[80]), .solved(cell_solved[80]) );

endmodule

// FIXME: relocate this elsewhere
// 1        2        3             4        5        6             7        8        9
// 123456789123456789123456789     123456789123456789123456789     123456789123456789123456789
// 123456781234567812345678123456781234567812345678123456781234567812345678123456781234567812345678
// 1       2       3       4       5       6       7       8       9       0       1       2
// 1                               2                               3

// 1 1 1 | 1 1 1 | 1 1 1
// 2 2 2 | 2 2 2 | 2 2 2
// 3 3 3 | 3 3 3 | 3 3 3

// 4 4 4 | 4 4 4 | 4 4 4
// 5 5 5 | 5 5 5 | 5 5 5
// 6 6 6 | 6 6 6 | 6 6 6

// 7 7 7 | 7 7 7 | 7 7 7
// 8 8 8 | 8 8 8 | 8 8 8
// 9 9 9 | 9 9 9 | 9 9 9

// 0       1       2       3        4       5         6       7
// 01234567012345670123456701234567 0123456701234567890123456701234567
// 1111    2222    3333             4444    5555      6666            777788889999

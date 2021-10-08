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
module sudoku_cell (
  input wire clk,
  input wire reset,

  input wire [9:1] wdata,
  output wire [9:1] rdata,

  input wire address,
  input wire we,

  input wire latch_singleton,

  output wire is_singleton,
  output wire is_illegal,
  output wire solved
);

reg [9:1] value;
reg [9:1] valid;

assign is_singleton = (valid[9]+valid[8]+valid[7]+valid[6]+valid[5]+valid[4]+valid[3]+valid[2]+valid[1]) == 1;
assign is_illegal   = value == 0 && (valid[9]+valid[8]+valid[7]+valid[6]+valid[5]+valid[4]+valid[3]+valid[2]+valid[1]) == 0;
assign solved = value != 0;

assign rdata = ( address == 0 ? value : valid );

always @(posedge clk) begin
  if ( reset ) begin
    value <= 0;
    valid <= ~0;
  end else begin
    if ( we ) begin
      if ( address == 0 ) begin
        value <= wdata;
        valid <= (wdata == 0) ? ~0 : 0;
      end else begin
        valid <= (value == 0) ? valid & wdata : 0;
      end
    end else if ( latch_singleton ) begin
      if ( is_singleton && value == 0 ) begin
        value <= valid;
        valid <= 0;
      end/* else
        valid <= (value == 0) ? ~0 : 0;*/
    end
  end
end 

endmodule


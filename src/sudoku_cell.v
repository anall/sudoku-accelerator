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
      end else
        valid <= (value == 0) ? ~0 : 0;
    end
  end
end 

endmodule


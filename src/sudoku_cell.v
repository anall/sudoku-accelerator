`default_nettype none
`timescale 1ns/1ns
module sudoku_cell (
  input wire clk,
  input wire reset,

  // Provided externally
  inout wire [9:1] value_io,

  input wire [1:0] address,
  input wire we,
  input wire oe,

  input wire latch_valid,
  input wire latch_singleton,

  output wire is_singleton,
  output wire solved
);

reg [9:1] value;
reg [9:1] pencil_out;
reg [9:1] requested_out = 'z;
reg [9:1] valid;

assign is_singleton = (valid[9]+valid[8]+valid[7]+valid[6]+valid[5]+valid[4]+valid[3]+valid[2]+valid[1]) == 1;
assign solved = value != 0;

assign value_io = ( ~oe ? 'z : (
  address == 0 ? value :
  address == 1 ? pencil_out :
  address == 2 ? valid : 'z ) );

always @(posedge clk) begin
  if ( reset ) begin
    value <= 0;
    pencil_out <= 0;
    valid <= ~pencil_out;
  end else begin
    if ( we ) begin
      if ( address == 0 ) begin
        value <= value_io;
        valid <= (value_io == 0) ? ~pencil_out : 0;
      end else if ( address == 1 ) begin
        pencil_out <= value_io;
        valid <= (value == 0) ? ~value_io : 0;
      end
    end else if ( latch_valid )
      valid <= (value == 0) ? valid & value_io : 0;
    else if ( latch_singleton ) begin
      if ( is_singleton && value == 0 ) begin
        value <= valid;
        valid <= 0;
      end else
        valid <= (value == 0) ? ~pencil_out : 0;
    end
  end
end 

endmodule


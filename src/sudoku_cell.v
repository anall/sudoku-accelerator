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
reg [9:1] requested_out;
reg [9:1] valid;

assign is_singleton = (valid[9]+valid[8]+valid[7]+valid[6]+valid[5]+valid[4]+valid[3]+valid[2]+valid[1]) == 1;
assign solved = value != 0;

assign value_io = requested_out;

// Does this need to be registered?
always @(oe,address) begin
  if (oe)
    case (address)
      0: requested_out = value;
      1: requested_out = pencil_out;
      2: requested_out = valid;
    endcase
  else
    requested_out = 'z;
end

reg [9:0] p_valid;

always @(posedge clk) begin
  if ( reset ) begin
    value <= 0;
    pencil_out <= 0;
    valid <= ~pencil_out;
  end else begin
    if ( we ) begin
      if ( address == 0 )
        value <= value_io;
      else if ( address == 1 ) begin
        pencil_out <= value_io;
        valid <= ~value_io;
      end
    end else if ( latch_valid && value == 0 )
      valid <= valid & value_io;
    else if ( latch_singleton ) begin
      if ( is_singleton ) begin
        value <= valid;
        valid <= 0;
      end else
        valid <= ~pencil_out;
    end
  end
end 

endmodule


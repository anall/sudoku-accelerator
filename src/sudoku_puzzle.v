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
  inout wire [80:0] data,

  // ttaaaa - 2 bits for type, 4 for address
  inout wire [5:0] address,

  // low/med/high oe/we
  input wire oe,
  input wire [2:0] we,

  input wire start_solve,

  output wire busy,
  output wire solved,
  output reg stuck
);

wire [9:1] values [80:0];

wire [9:1] valid_row [8:0];
wire [9:1] valid_col [8:0];
wire [9:1] valid_box [8:0];

reg latch_valid = 0;
reg latch_singleton = 0;

localparam STATE_IDLE    = 0;
localparam STATE_LVALID  = 1;
localparam STATE_LSINGLE = 2;

reg [2:0] state = STATE_IDLE;

assign busy = state != STATE_IDLE;
wire [2:0] we_nb = busy ? '0 : we; 

reg [8:0] row_e;
always @(address) begin
  case (address[3:0])
    0: row_e = 9'b000000001;
    1: row_e = 9'b000000010;
    2: row_e = 9'b000000100;
    3: row_e = 9'b000001000;
    4: row_e = 9'b000010000;
    5: row_e = 9'b000100000;
    6: row_e = 9'b001000000;
    7: row_e = 9'b010000000;
    8: row_e = 9'b100000000;
    default: row_e = 0;
  endcase
end

wire [80:0] cell_singleton;
wire [80:0] cell_solved;
wire is_singleton;

wire [1:0] cell_addr = address[5:4];

always @(posedge clk) begin
  if ( reset ) begin
    state <= STATE_IDLE;
    stuck <= 0;
  end else if ( busy ) begin // busy means 'not STATE_IDLE'
    if ( state == STATE_LVALID ) begin
      latch_valid <= 0;
      latch_singleton <= ~solved;
      state <= solved ? STATE_IDLE : STATE_LSINGLE;
    end else if ( state == STATE_LSINGLE ) begin
      latch_singleton <= 0;
      latch_valid <= is_singleton;
      state <= is_singleton ? STATE_LVALID : STATE_IDLE;
      stuck <= ~is_singleton;
    end
  end else if ( start_solve ) begin
    latch_singleton <= 0;
    latch_valid <= ~solved;
    state <= solved ? STATE_IDLE : STATE_LVALID;
    stuck <= 0;
  end
end

// -----GENERATED CODE FOLLOWS-----
// This garbage generated using tools/generate_cells.pl
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

sudoku_cell cell00( .clk(clk), .reset(reset), .value_io(data[8:0]),
  .address(cell_addr), .we(row_e[0] & we_nb[0]), .oe(row_e[0] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[0]),
  .valid_row(valid_row[0]), .valid_col(valid_col[0]), .valid_box(valid_box[0]),
  .is_singleton(cell_singleton[0]), .solved(cell_solved[0]) );
sudoku_cell cell01( .clk(clk), .reset(reset), .value_io(data[17:9]),
  .address(cell_addr), .we(row_e[0] & we_nb[0]), .oe(row_e[0] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[1]),
  .valid_row(valid_row[0]), .valid_col(valid_col[1]), .valid_box(valid_box[0]),
  .is_singleton(cell_singleton[1]), .solved(cell_solved[1]) );
sudoku_cell cell02( .clk(clk), .reset(reset), .value_io(data[26:18]),
  .address(cell_addr), .we(row_e[0] & we_nb[0]), .oe(row_e[0] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[2]),
  .valid_row(valid_row[0]), .valid_col(valid_col[2]), .valid_box(valid_box[0]),
  .is_singleton(cell_singleton[2]), .solved(cell_solved[2]) );
sudoku_cell cell03( .clk(clk), .reset(reset), .value_io(data[35:27]),
  .address(cell_addr), .we(row_e[0] & we_nb[1]), .oe(row_e[0] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[3]),
  .valid_row(valid_row[0]), .valid_col(valid_col[3]), .valid_box(valid_box[1]),
  .is_singleton(cell_singleton[3]), .solved(cell_solved[3]) );
sudoku_cell cell04( .clk(clk), .reset(reset), .value_io(data[44:36]),
  .address(cell_addr), .we(row_e[0] & we_nb[1]), .oe(row_e[0] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[4]),
  .valid_row(valid_row[0]), .valid_col(valid_col[4]), .valid_box(valid_box[1]),
  .is_singleton(cell_singleton[4]), .solved(cell_solved[4]) );
sudoku_cell cell05( .clk(clk), .reset(reset), .value_io(data[53:45]),
  .address(cell_addr), .we(row_e[0] & we_nb[1]), .oe(row_e[0] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[5]),
  .valid_row(valid_row[0]), .valid_col(valid_col[5]), .valid_box(valid_box[1]),
  .is_singleton(cell_singleton[5]), .solved(cell_solved[5]) );
sudoku_cell cell06( .clk(clk), .reset(reset), .value_io(data[62:54]),
  .address(cell_addr), .we(row_e[0] & we_nb[2]), .oe(row_e[0] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[6]),
  .valid_row(valid_row[0]), .valid_col(valid_col[6]), .valid_box(valid_box[2]),
  .is_singleton(cell_singleton[6]), .solved(cell_solved[6]) );
sudoku_cell cell07( .clk(clk), .reset(reset), .value_io(data[71:63]),
  .address(cell_addr), .we(row_e[0] & we_nb[2]), .oe(row_e[0] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[7]),
  .valid_row(valid_row[0]), .valid_col(valid_col[7]), .valid_box(valid_box[2]),
  .is_singleton(cell_singleton[7]), .solved(cell_solved[7]) );
sudoku_cell cell08( .clk(clk), .reset(reset), .value_io(data[80:72]),
  .address(cell_addr), .we(row_e[0] & we_nb[2]), .oe(row_e[0] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[8]),
  .valid_row(valid_row[0]), .valid_col(valid_col[8]), .valid_box(valid_box[2]),
  .is_singleton(cell_singleton[8]), .solved(cell_solved[8]) );
sudoku_cell cell10( .clk(clk), .reset(reset), .value_io(data[8:0]),
  .address(cell_addr), .we(row_e[1] & we_nb[0]), .oe(row_e[1] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[9]),
  .valid_row(valid_row[1]), .valid_col(valid_col[0]), .valid_box(valid_box[0]),
  .is_singleton(cell_singleton[9]), .solved(cell_solved[9]) );
sudoku_cell cell11( .clk(clk), .reset(reset), .value_io(data[17:9]),
  .address(cell_addr), .we(row_e[1] & we_nb[0]), .oe(row_e[1] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[10]),
  .valid_row(valid_row[1]), .valid_col(valid_col[1]), .valid_box(valid_box[0]),
  .is_singleton(cell_singleton[10]), .solved(cell_solved[10]) );
sudoku_cell cell12( .clk(clk), .reset(reset), .value_io(data[26:18]),
  .address(cell_addr), .we(row_e[1] & we_nb[0]), .oe(row_e[1] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[11]),
  .valid_row(valid_row[1]), .valid_col(valid_col[2]), .valid_box(valid_box[0]),
  .is_singleton(cell_singleton[11]), .solved(cell_solved[11]) );
sudoku_cell cell13( .clk(clk), .reset(reset), .value_io(data[35:27]),
  .address(cell_addr), .we(row_e[1] & we_nb[1]), .oe(row_e[1] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[12]),
  .valid_row(valid_row[1]), .valid_col(valid_col[3]), .valid_box(valid_box[1]),
  .is_singleton(cell_singleton[12]), .solved(cell_solved[12]) );
sudoku_cell cell14( .clk(clk), .reset(reset), .value_io(data[44:36]),
  .address(cell_addr), .we(row_e[1] & we_nb[1]), .oe(row_e[1] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[13]),
  .valid_row(valid_row[1]), .valid_col(valid_col[4]), .valid_box(valid_box[1]),
  .is_singleton(cell_singleton[13]), .solved(cell_solved[13]) );
sudoku_cell cell15( .clk(clk), .reset(reset), .value_io(data[53:45]),
  .address(cell_addr), .we(row_e[1] & we_nb[1]), .oe(row_e[1] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[14]),
  .valid_row(valid_row[1]), .valid_col(valid_col[5]), .valid_box(valid_box[1]),
  .is_singleton(cell_singleton[14]), .solved(cell_solved[14]) );
sudoku_cell cell16( .clk(clk), .reset(reset), .value_io(data[62:54]),
  .address(cell_addr), .we(row_e[1] & we_nb[2]), .oe(row_e[1] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[15]),
  .valid_row(valid_row[1]), .valid_col(valid_col[6]), .valid_box(valid_box[2]),
  .is_singleton(cell_singleton[15]), .solved(cell_solved[15]) );
sudoku_cell cell17( .clk(clk), .reset(reset), .value_io(data[71:63]),
  .address(cell_addr), .we(row_e[1] & we_nb[2]), .oe(row_e[1] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[16]),
  .valid_row(valid_row[1]), .valid_col(valid_col[7]), .valid_box(valid_box[2]),
  .is_singleton(cell_singleton[16]), .solved(cell_solved[16]) );
sudoku_cell cell18( .clk(clk), .reset(reset), .value_io(data[80:72]),
  .address(cell_addr), .we(row_e[1] & we_nb[2]), .oe(row_e[1] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[17]),
  .valid_row(valid_row[1]), .valid_col(valid_col[8]), .valid_box(valid_box[2]),
  .is_singleton(cell_singleton[17]), .solved(cell_solved[17]) );
sudoku_cell cell20( .clk(clk), .reset(reset), .value_io(data[8:0]),
  .address(cell_addr), .we(row_e[2] & we_nb[0]), .oe(row_e[2] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[18]),
  .valid_row(valid_row[2]), .valid_col(valid_col[0]), .valid_box(valid_box[0]),
  .is_singleton(cell_singleton[18]), .solved(cell_solved[18]) );
sudoku_cell cell21( .clk(clk), .reset(reset), .value_io(data[17:9]),
  .address(cell_addr), .we(row_e[2] & we_nb[0]), .oe(row_e[2] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[19]),
  .valid_row(valid_row[2]), .valid_col(valid_col[1]), .valid_box(valid_box[0]),
  .is_singleton(cell_singleton[19]), .solved(cell_solved[19]) );
sudoku_cell cell22( .clk(clk), .reset(reset), .value_io(data[26:18]),
  .address(cell_addr), .we(row_e[2] & we_nb[0]), .oe(row_e[2] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[20]),
  .valid_row(valid_row[2]), .valid_col(valid_col[2]), .valid_box(valid_box[0]),
  .is_singleton(cell_singleton[20]), .solved(cell_solved[20]) );
sudoku_cell cell23( .clk(clk), .reset(reset), .value_io(data[35:27]),
  .address(cell_addr), .we(row_e[2] & we_nb[1]), .oe(row_e[2] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[21]),
  .valid_row(valid_row[2]), .valid_col(valid_col[3]), .valid_box(valid_box[1]),
  .is_singleton(cell_singleton[21]), .solved(cell_solved[21]) );
sudoku_cell cell24( .clk(clk), .reset(reset), .value_io(data[44:36]),
  .address(cell_addr), .we(row_e[2] & we_nb[1]), .oe(row_e[2] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[22]),
  .valid_row(valid_row[2]), .valid_col(valid_col[4]), .valid_box(valid_box[1]),
  .is_singleton(cell_singleton[22]), .solved(cell_solved[22]) );
sudoku_cell cell25( .clk(clk), .reset(reset), .value_io(data[53:45]),
  .address(cell_addr), .we(row_e[2] & we_nb[1]), .oe(row_e[2] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[23]),
  .valid_row(valid_row[2]), .valid_col(valid_col[5]), .valid_box(valid_box[1]),
  .is_singleton(cell_singleton[23]), .solved(cell_solved[23]) );
sudoku_cell cell26( .clk(clk), .reset(reset), .value_io(data[62:54]),
  .address(cell_addr), .we(row_e[2] & we_nb[2]), .oe(row_e[2] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[24]),
  .valid_row(valid_row[2]), .valid_col(valid_col[6]), .valid_box(valid_box[2]),
  .is_singleton(cell_singleton[24]), .solved(cell_solved[24]) );
sudoku_cell cell27( .clk(clk), .reset(reset), .value_io(data[71:63]),
  .address(cell_addr), .we(row_e[2] & we_nb[2]), .oe(row_e[2] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[25]),
  .valid_row(valid_row[2]), .valid_col(valid_col[7]), .valid_box(valid_box[2]),
  .is_singleton(cell_singleton[25]), .solved(cell_solved[25]) );
sudoku_cell cell28( .clk(clk), .reset(reset), .value_io(data[80:72]),
  .address(cell_addr), .we(row_e[2] & we_nb[2]), .oe(row_e[2] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[26]),
  .valid_row(valid_row[2]), .valid_col(valid_col[8]), .valid_box(valid_box[2]),
  .is_singleton(cell_singleton[26]), .solved(cell_solved[26]) );
sudoku_cell cell30( .clk(clk), .reset(reset), .value_io(data[8:0]),
  .address(cell_addr), .we(row_e[3] & we_nb[0]), .oe(row_e[3] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[27]),
  .valid_row(valid_row[3]), .valid_col(valid_col[0]), .valid_box(valid_box[3]),
  .is_singleton(cell_singleton[27]), .solved(cell_solved[27]) );
sudoku_cell cell31( .clk(clk), .reset(reset), .value_io(data[17:9]),
  .address(cell_addr), .we(row_e[3] & we_nb[0]), .oe(row_e[3] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[28]),
  .valid_row(valid_row[3]), .valid_col(valid_col[1]), .valid_box(valid_box[3]),
  .is_singleton(cell_singleton[28]), .solved(cell_solved[28]) );
sudoku_cell cell32( .clk(clk), .reset(reset), .value_io(data[26:18]),
  .address(cell_addr), .we(row_e[3] & we_nb[0]), .oe(row_e[3] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[29]),
  .valid_row(valid_row[3]), .valid_col(valid_col[2]), .valid_box(valid_box[3]),
  .is_singleton(cell_singleton[29]), .solved(cell_solved[29]) );
sudoku_cell cell33( .clk(clk), .reset(reset), .value_io(data[35:27]),
  .address(cell_addr), .we(row_e[3] & we_nb[1]), .oe(row_e[3] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[30]),
  .valid_row(valid_row[3]), .valid_col(valid_col[3]), .valid_box(valid_box[4]),
  .is_singleton(cell_singleton[30]), .solved(cell_solved[30]) );
sudoku_cell cell34( .clk(clk), .reset(reset), .value_io(data[44:36]),
  .address(cell_addr), .we(row_e[3] & we_nb[1]), .oe(row_e[3] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[31]),
  .valid_row(valid_row[3]), .valid_col(valid_col[4]), .valid_box(valid_box[4]),
  .is_singleton(cell_singleton[31]), .solved(cell_solved[31]) );
sudoku_cell cell35( .clk(clk), .reset(reset), .value_io(data[53:45]),
  .address(cell_addr), .we(row_e[3] & we_nb[1]), .oe(row_e[3] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[32]),
  .valid_row(valid_row[3]), .valid_col(valid_col[5]), .valid_box(valid_box[4]),
  .is_singleton(cell_singleton[32]), .solved(cell_solved[32]) );
sudoku_cell cell36( .clk(clk), .reset(reset), .value_io(data[62:54]),
  .address(cell_addr), .we(row_e[3] & we_nb[2]), .oe(row_e[3] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[33]),
  .valid_row(valid_row[3]), .valid_col(valid_col[6]), .valid_box(valid_box[5]),
  .is_singleton(cell_singleton[33]), .solved(cell_solved[33]) );
sudoku_cell cell37( .clk(clk), .reset(reset), .value_io(data[71:63]),
  .address(cell_addr), .we(row_e[3] & we_nb[2]), .oe(row_e[3] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[34]),
  .valid_row(valid_row[3]), .valid_col(valid_col[7]), .valid_box(valid_box[5]),
  .is_singleton(cell_singleton[34]), .solved(cell_solved[34]) );
sudoku_cell cell38( .clk(clk), .reset(reset), .value_io(data[80:72]),
  .address(cell_addr), .we(row_e[3] & we_nb[2]), .oe(row_e[3] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[35]),
  .valid_row(valid_row[3]), .valid_col(valid_col[8]), .valid_box(valid_box[5]),
  .is_singleton(cell_singleton[35]), .solved(cell_solved[35]) );
sudoku_cell cell40( .clk(clk), .reset(reset), .value_io(data[8:0]),
  .address(cell_addr), .we(row_e[4] & we_nb[0]), .oe(row_e[4] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[36]),
  .valid_row(valid_row[4]), .valid_col(valid_col[0]), .valid_box(valid_box[3]),
  .is_singleton(cell_singleton[36]), .solved(cell_solved[36]) );
sudoku_cell cell41( .clk(clk), .reset(reset), .value_io(data[17:9]),
  .address(cell_addr), .we(row_e[4] & we_nb[0]), .oe(row_e[4] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[37]),
  .valid_row(valid_row[4]), .valid_col(valid_col[1]), .valid_box(valid_box[3]),
  .is_singleton(cell_singleton[37]), .solved(cell_solved[37]) );
sudoku_cell cell42( .clk(clk), .reset(reset), .value_io(data[26:18]),
  .address(cell_addr), .we(row_e[4] & we_nb[0]), .oe(row_e[4] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[38]),
  .valid_row(valid_row[4]), .valid_col(valid_col[2]), .valid_box(valid_box[3]),
  .is_singleton(cell_singleton[38]), .solved(cell_solved[38]) );
sudoku_cell cell43( .clk(clk), .reset(reset), .value_io(data[35:27]),
  .address(cell_addr), .we(row_e[4] & we_nb[1]), .oe(row_e[4] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[39]),
  .valid_row(valid_row[4]), .valid_col(valid_col[3]), .valid_box(valid_box[4]),
  .is_singleton(cell_singleton[39]), .solved(cell_solved[39]) );
sudoku_cell cell44( .clk(clk), .reset(reset), .value_io(data[44:36]),
  .address(cell_addr), .we(row_e[4] & we_nb[1]), .oe(row_e[4] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[40]),
  .valid_row(valid_row[4]), .valid_col(valid_col[4]), .valid_box(valid_box[4]),
  .is_singleton(cell_singleton[40]), .solved(cell_solved[40]) );
sudoku_cell cell45( .clk(clk), .reset(reset), .value_io(data[53:45]),
  .address(cell_addr), .we(row_e[4] & we_nb[1]), .oe(row_e[4] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[41]),
  .valid_row(valid_row[4]), .valid_col(valid_col[5]), .valid_box(valid_box[4]),
  .is_singleton(cell_singleton[41]), .solved(cell_solved[41]) );
sudoku_cell cell46( .clk(clk), .reset(reset), .value_io(data[62:54]),
  .address(cell_addr), .we(row_e[4] & we_nb[2]), .oe(row_e[4] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[42]),
  .valid_row(valid_row[4]), .valid_col(valid_col[6]), .valid_box(valid_box[5]),
  .is_singleton(cell_singleton[42]), .solved(cell_solved[42]) );
sudoku_cell cell47( .clk(clk), .reset(reset), .value_io(data[71:63]),
  .address(cell_addr), .we(row_e[4] & we_nb[2]), .oe(row_e[4] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[43]),
  .valid_row(valid_row[4]), .valid_col(valid_col[7]), .valid_box(valid_box[5]),
  .is_singleton(cell_singleton[43]), .solved(cell_solved[43]) );
sudoku_cell cell48( .clk(clk), .reset(reset), .value_io(data[80:72]),
  .address(cell_addr), .we(row_e[4] & we_nb[2]), .oe(row_e[4] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[44]),
  .valid_row(valid_row[4]), .valid_col(valid_col[8]), .valid_box(valid_box[5]),
  .is_singleton(cell_singleton[44]), .solved(cell_solved[44]) );
sudoku_cell cell50( .clk(clk), .reset(reset), .value_io(data[8:0]),
  .address(cell_addr), .we(row_e[5] & we_nb[0]), .oe(row_e[5] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[45]),
  .valid_row(valid_row[5]), .valid_col(valid_col[0]), .valid_box(valid_box[3]),
  .is_singleton(cell_singleton[45]), .solved(cell_solved[45]) );
sudoku_cell cell51( .clk(clk), .reset(reset), .value_io(data[17:9]),
  .address(cell_addr), .we(row_e[5] & we_nb[0]), .oe(row_e[5] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[46]),
  .valid_row(valid_row[5]), .valid_col(valid_col[1]), .valid_box(valid_box[3]),
  .is_singleton(cell_singleton[46]), .solved(cell_solved[46]) );
sudoku_cell cell52( .clk(clk), .reset(reset), .value_io(data[26:18]),
  .address(cell_addr), .we(row_e[5] & we_nb[0]), .oe(row_e[5] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[47]),
  .valid_row(valid_row[5]), .valid_col(valid_col[2]), .valid_box(valid_box[3]),
  .is_singleton(cell_singleton[47]), .solved(cell_solved[47]) );
sudoku_cell cell53( .clk(clk), .reset(reset), .value_io(data[35:27]),
  .address(cell_addr), .we(row_e[5] & we_nb[1]), .oe(row_e[5] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[48]),
  .valid_row(valid_row[5]), .valid_col(valid_col[3]), .valid_box(valid_box[4]),
  .is_singleton(cell_singleton[48]), .solved(cell_solved[48]) );
sudoku_cell cell54( .clk(clk), .reset(reset), .value_io(data[44:36]),
  .address(cell_addr), .we(row_e[5] & we_nb[1]), .oe(row_e[5] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[49]),
  .valid_row(valid_row[5]), .valid_col(valid_col[4]), .valid_box(valid_box[4]),
  .is_singleton(cell_singleton[49]), .solved(cell_solved[49]) );
sudoku_cell cell55( .clk(clk), .reset(reset), .value_io(data[53:45]),
  .address(cell_addr), .we(row_e[5] & we_nb[1]), .oe(row_e[5] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[50]),
  .valid_row(valid_row[5]), .valid_col(valid_col[5]), .valid_box(valid_box[4]),
  .is_singleton(cell_singleton[50]), .solved(cell_solved[50]) );
sudoku_cell cell56( .clk(clk), .reset(reset), .value_io(data[62:54]),
  .address(cell_addr), .we(row_e[5] & we_nb[2]), .oe(row_e[5] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[51]),
  .valid_row(valid_row[5]), .valid_col(valid_col[6]), .valid_box(valid_box[5]),
  .is_singleton(cell_singleton[51]), .solved(cell_solved[51]) );
sudoku_cell cell57( .clk(clk), .reset(reset), .value_io(data[71:63]),
  .address(cell_addr), .we(row_e[5] & we_nb[2]), .oe(row_e[5] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[52]),
  .valid_row(valid_row[5]), .valid_col(valid_col[7]), .valid_box(valid_box[5]),
  .is_singleton(cell_singleton[52]), .solved(cell_solved[52]) );
sudoku_cell cell58( .clk(clk), .reset(reset), .value_io(data[80:72]),
  .address(cell_addr), .we(row_e[5] & we_nb[2]), .oe(row_e[5] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[53]),
  .valid_row(valid_row[5]), .valid_col(valid_col[8]), .valid_box(valid_box[5]),
  .is_singleton(cell_singleton[53]), .solved(cell_solved[53]) );
sudoku_cell cell60( .clk(clk), .reset(reset), .value_io(data[8:0]),
  .address(cell_addr), .we(row_e[6] & we_nb[0]), .oe(row_e[6] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[54]),
  .valid_row(valid_row[6]), .valid_col(valid_col[0]), .valid_box(valid_box[6]),
  .is_singleton(cell_singleton[54]), .solved(cell_solved[54]) );
sudoku_cell cell61( .clk(clk), .reset(reset), .value_io(data[17:9]),
  .address(cell_addr), .we(row_e[6] & we_nb[0]), .oe(row_e[6] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[55]),
  .valid_row(valid_row[6]), .valid_col(valid_col[1]), .valid_box(valid_box[6]),
  .is_singleton(cell_singleton[55]), .solved(cell_solved[55]) );
sudoku_cell cell62( .clk(clk), .reset(reset), .value_io(data[26:18]),
  .address(cell_addr), .we(row_e[6] & we_nb[0]), .oe(row_e[6] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[56]),
  .valid_row(valid_row[6]), .valid_col(valid_col[2]), .valid_box(valid_box[6]),
  .is_singleton(cell_singleton[56]), .solved(cell_solved[56]) );
sudoku_cell cell63( .clk(clk), .reset(reset), .value_io(data[35:27]),
  .address(cell_addr), .we(row_e[6] & we_nb[1]), .oe(row_e[6] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[57]),
  .valid_row(valid_row[6]), .valid_col(valid_col[3]), .valid_box(valid_box[7]),
  .is_singleton(cell_singleton[57]), .solved(cell_solved[57]) );
sudoku_cell cell64( .clk(clk), .reset(reset), .value_io(data[44:36]),
  .address(cell_addr), .we(row_e[6] & we_nb[1]), .oe(row_e[6] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[58]),
  .valid_row(valid_row[6]), .valid_col(valid_col[4]), .valid_box(valid_box[7]),
  .is_singleton(cell_singleton[58]), .solved(cell_solved[58]) );
sudoku_cell cell65( .clk(clk), .reset(reset), .value_io(data[53:45]),
  .address(cell_addr), .we(row_e[6] & we_nb[1]), .oe(row_e[6] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[59]),
  .valid_row(valid_row[6]), .valid_col(valid_col[5]), .valid_box(valid_box[7]),
  .is_singleton(cell_singleton[59]), .solved(cell_solved[59]) );
sudoku_cell cell66( .clk(clk), .reset(reset), .value_io(data[62:54]),
  .address(cell_addr), .we(row_e[6] & we_nb[2]), .oe(row_e[6] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[60]),
  .valid_row(valid_row[6]), .valid_col(valid_col[6]), .valid_box(valid_box[8]),
  .is_singleton(cell_singleton[60]), .solved(cell_solved[60]) );
sudoku_cell cell67( .clk(clk), .reset(reset), .value_io(data[71:63]),
  .address(cell_addr), .we(row_e[6] & we_nb[2]), .oe(row_e[6] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[61]),
  .valid_row(valid_row[6]), .valid_col(valid_col[7]), .valid_box(valid_box[8]),
  .is_singleton(cell_singleton[61]), .solved(cell_solved[61]) );
sudoku_cell cell68( .clk(clk), .reset(reset), .value_io(data[80:72]),
  .address(cell_addr), .we(row_e[6] & we_nb[2]), .oe(row_e[6] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[62]),
  .valid_row(valid_row[6]), .valid_col(valid_col[8]), .valid_box(valid_box[8]),
  .is_singleton(cell_singleton[62]), .solved(cell_solved[62]) );
sudoku_cell cell70( .clk(clk), .reset(reset), .value_io(data[8:0]),
  .address(cell_addr), .we(row_e[7] & we_nb[0]), .oe(row_e[7] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[63]),
  .valid_row(valid_row[7]), .valid_col(valid_col[0]), .valid_box(valid_box[6]),
  .is_singleton(cell_singleton[63]), .solved(cell_solved[63]) );
sudoku_cell cell71( .clk(clk), .reset(reset), .value_io(data[17:9]),
  .address(cell_addr), .we(row_e[7] & we_nb[0]), .oe(row_e[7] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[64]),
  .valid_row(valid_row[7]), .valid_col(valid_col[1]), .valid_box(valid_box[6]),
  .is_singleton(cell_singleton[64]), .solved(cell_solved[64]) );
sudoku_cell cell72( .clk(clk), .reset(reset), .value_io(data[26:18]),
  .address(cell_addr), .we(row_e[7] & we_nb[0]), .oe(row_e[7] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[65]),
  .valid_row(valid_row[7]), .valid_col(valid_col[2]), .valid_box(valid_box[6]),
  .is_singleton(cell_singleton[65]), .solved(cell_solved[65]) );
sudoku_cell cell73( .clk(clk), .reset(reset), .value_io(data[35:27]),
  .address(cell_addr), .we(row_e[7] & we_nb[1]), .oe(row_e[7] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[66]),
  .valid_row(valid_row[7]), .valid_col(valid_col[3]), .valid_box(valid_box[7]),
  .is_singleton(cell_singleton[66]), .solved(cell_solved[66]) );
sudoku_cell cell74( .clk(clk), .reset(reset), .value_io(data[44:36]),
  .address(cell_addr), .we(row_e[7] & we_nb[1]), .oe(row_e[7] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[67]),
  .valid_row(valid_row[7]), .valid_col(valid_col[4]), .valid_box(valid_box[7]),
  .is_singleton(cell_singleton[67]), .solved(cell_solved[67]) );
sudoku_cell cell75( .clk(clk), .reset(reset), .value_io(data[53:45]),
  .address(cell_addr), .we(row_e[7] & we_nb[1]), .oe(row_e[7] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[68]),
  .valid_row(valid_row[7]), .valid_col(valid_col[5]), .valid_box(valid_box[7]),
  .is_singleton(cell_singleton[68]), .solved(cell_solved[68]) );
sudoku_cell cell76( .clk(clk), .reset(reset), .value_io(data[62:54]),
  .address(cell_addr), .we(row_e[7] & we_nb[2]), .oe(row_e[7] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[69]),
  .valid_row(valid_row[7]), .valid_col(valid_col[6]), .valid_box(valid_box[8]),
  .is_singleton(cell_singleton[69]), .solved(cell_solved[69]) );
sudoku_cell cell77( .clk(clk), .reset(reset), .value_io(data[71:63]),
  .address(cell_addr), .we(row_e[7] & we_nb[2]), .oe(row_e[7] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[70]),
  .valid_row(valid_row[7]), .valid_col(valid_col[7]), .valid_box(valid_box[8]),
  .is_singleton(cell_singleton[70]), .solved(cell_solved[70]) );
sudoku_cell cell78( .clk(clk), .reset(reset), .value_io(data[80:72]),
  .address(cell_addr), .we(row_e[7] & we_nb[2]), .oe(row_e[7] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[71]),
  .valid_row(valid_row[7]), .valid_col(valid_col[8]), .valid_box(valid_box[8]),
  .is_singleton(cell_singleton[71]), .solved(cell_solved[71]) );
sudoku_cell cell80( .clk(clk), .reset(reset), .value_io(data[8:0]),
  .address(cell_addr), .we(row_e[8] & we_nb[0]), .oe(row_e[8] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[72]),
  .valid_row(valid_row[8]), .valid_col(valid_col[0]), .valid_box(valid_box[6]),
  .is_singleton(cell_singleton[72]), .solved(cell_solved[72]) );
sudoku_cell cell81( .clk(clk), .reset(reset), .value_io(data[17:9]),
  .address(cell_addr), .we(row_e[8] & we_nb[0]), .oe(row_e[8] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[73]),
  .valid_row(valid_row[8]), .valid_col(valid_col[1]), .valid_box(valid_box[6]),
  .is_singleton(cell_singleton[73]), .solved(cell_solved[73]) );
sudoku_cell cell82( .clk(clk), .reset(reset), .value_io(data[26:18]),
  .address(cell_addr), .we(row_e[8] & we_nb[0]), .oe(row_e[8] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[74]),
  .valid_row(valid_row[8]), .valid_col(valid_col[2]), .valid_box(valid_box[6]),
  .is_singleton(cell_singleton[74]), .solved(cell_solved[74]) );
sudoku_cell cell83( .clk(clk), .reset(reset), .value_io(data[35:27]),
  .address(cell_addr), .we(row_e[8] & we_nb[1]), .oe(row_e[8] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[75]),
  .valid_row(valid_row[8]), .valid_col(valid_col[3]), .valid_box(valid_box[7]),
  .is_singleton(cell_singleton[75]), .solved(cell_solved[75]) );
sudoku_cell cell84( .clk(clk), .reset(reset), .value_io(data[44:36]),
  .address(cell_addr), .we(row_e[8] & we_nb[1]), .oe(row_e[8] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[76]),
  .valid_row(valid_row[8]), .valid_col(valid_col[4]), .valid_box(valid_box[7]),
  .is_singleton(cell_singleton[76]), .solved(cell_solved[76]) );
sudoku_cell cell85( .clk(clk), .reset(reset), .value_io(data[53:45]),
  .address(cell_addr), .we(row_e[8] & we_nb[1]), .oe(row_e[8] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[77]),
  .valid_row(valid_row[8]), .valid_col(valid_col[5]), .valid_box(valid_box[7]),
  .is_singleton(cell_singleton[77]), .solved(cell_solved[77]) );
sudoku_cell cell86( .clk(clk), .reset(reset), .value_io(data[62:54]),
  .address(cell_addr), .we(row_e[8] & we_nb[2]), .oe(row_e[8] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[78]),
  .valid_row(valid_row[8]), .valid_col(valid_col[6]), .valid_box(valid_box[8]),
  .is_singleton(cell_singleton[78]), .solved(cell_solved[78]) );
sudoku_cell cell87( .clk(clk), .reset(reset), .value_io(data[71:63]),
  .address(cell_addr), .we(row_e[8] & we_nb[2]), .oe(row_e[8] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[79]),
  .valid_row(valid_row[8]), .valid_col(valid_col[7]), .valid_box(valid_box[8]),
  .is_singleton(cell_singleton[79]), .solved(cell_solved[79]) );
sudoku_cell cell88( .clk(clk), .reset(reset), .value_io(data[80:72]),
  .address(cell_addr), .we(row_e[8] & we_nb[2]), .oe(row_e[8] & oe),
  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[80]),
  .valid_row(valid_row[8]), .valid_col(valid_col[8]), .valid_box(valid_box[8]),
  .is_singleton(cell_singleton[80]), .solved(cell_solved[80]) );
assign valid_row[0] = ~values[0] & ~values[1] & ~values[2] & ~values[3] & ~values[4] & ~values[5] & ~values[6] & ~values[7] & ~values[8];
assign valid_col[0] = ~values[0] & ~values[9] & ~values[18] & ~values[27] & ~values[36] & ~values[45] & ~values[54] & ~values[63] & ~values[72];
assign valid_box[0] = ~values[0] & ~values[1] & ~values[2] & ~values[9] & ~values[10] & ~values[11] & ~values[18] & ~values[19] & ~values[20];
assign valid_row[1] = ~values[9] & ~values[10] & ~values[11] & ~values[12] & ~values[13] & ~values[14] & ~values[15] & ~values[16] & ~values[17];
assign valid_col[1] = ~values[1] & ~values[10] & ~values[19] & ~values[28] & ~values[37] & ~values[46] & ~values[55] & ~values[64] & ~values[73];
assign valid_box[1] = ~values[3] & ~values[4] & ~values[5] & ~values[12] & ~values[13] & ~values[14] & ~values[21] & ~values[22] & ~values[23];
assign valid_row[2] = ~values[18] & ~values[19] & ~values[20] & ~values[21] & ~values[22] & ~values[23] & ~values[24] & ~values[25] & ~values[26];
assign valid_col[2] = ~values[2] & ~values[11] & ~values[20] & ~values[29] & ~values[38] & ~values[47] & ~values[56] & ~values[65] & ~values[74];
assign valid_box[2] = ~values[6] & ~values[7] & ~values[8] & ~values[15] & ~values[16] & ~values[17] & ~values[24] & ~values[25] & ~values[26];
assign valid_row[3] = ~values[27] & ~values[28] & ~values[29] & ~values[30] & ~values[31] & ~values[32] & ~values[33] & ~values[34] & ~values[35];
assign valid_col[3] = ~values[3] & ~values[12] & ~values[21] & ~values[30] & ~values[39] & ~values[48] & ~values[57] & ~values[66] & ~values[75];
assign valid_box[3] = ~values[27] & ~values[28] & ~values[29] & ~values[36] & ~values[37] & ~values[38] & ~values[45] & ~values[46] & ~values[47];
assign valid_row[4] = ~values[36] & ~values[37] & ~values[38] & ~values[39] & ~values[40] & ~values[41] & ~values[42] & ~values[43] & ~values[44];
assign valid_col[4] = ~values[4] & ~values[13] & ~values[22] & ~values[31] & ~values[40] & ~values[49] & ~values[58] & ~values[67] & ~values[76];
assign valid_box[4] = ~values[30] & ~values[31] & ~values[32] & ~values[39] & ~values[40] & ~values[41] & ~values[48] & ~values[49] & ~values[50];
assign valid_row[5] = ~values[45] & ~values[46] & ~values[47] & ~values[48] & ~values[49] & ~values[50] & ~values[51] & ~values[52] & ~values[53];
assign valid_col[5] = ~values[5] & ~values[14] & ~values[23] & ~values[32] & ~values[41] & ~values[50] & ~values[59] & ~values[68] & ~values[77];
assign valid_box[5] = ~values[33] & ~values[34] & ~values[35] & ~values[42] & ~values[43] & ~values[44] & ~values[51] & ~values[52] & ~values[53];
assign valid_row[6] = ~values[54] & ~values[55] & ~values[56] & ~values[57] & ~values[58] & ~values[59] & ~values[60] & ~values[61] & ~values[62];
assign valid_col[6] = ~values[6] & ~values[15] & ~values[24] & ~values[33] & ~values[42] & ~values[51] & ~values[60] & ~values[69] & ~values[78];
assign valid_box[6] = ~values[54] & ~values[55] & ~values[56] & ~values[63] & ~values[64] & ~values[65] & ~values[72] & ~values[73] & ~values[74];
assign valid_row[7] = ~values[63] & ~values[64] & ~values[65] & ~values[66] & ~values[67] & ~values[68] & ~values[69] & ~values[70] & ~values[71];
assign valid_col[7] = ~values[7] & ~values[16] & ~values[25] & ~values[34] & ~values[43] & ~values[52] & ~values[61] & ~values[70] & ~values[79];
assign valid_box[7] = ~values[57] & ~values[58] & ~values[59] & ~values[66] & ~values[67] & ~values[68] & ~values[75] & ~values[76] & ~values[77];
assign valid_row[8] = ~values[72] & ~values[73] & ~values[74] & ~values[75] & ~values[76] & ~values[77] & ~values[78] & ~values[79] & ~values[80];
assign valid_col[8] = ~values[8] & ~values[17] & ~values[26] & ~values[35] & ~values[44] & ~values[53] & ~values[62] & ~values[71] & ~values[80];
assign valid_box[8] = ~values[60] & ~values[61] & ~values[62] & ~values[69] & ~values[70] & ~values[71] & ~values[78] & ~values[79] & ~values[80];

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

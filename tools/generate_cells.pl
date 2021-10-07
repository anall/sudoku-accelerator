#!/usr/bin/perl
use v5.10;
use strict;
use warnings;

print "// Following generated using tools/generate_cells.pl\n";
my $is_singleton = "0";
my $is_illegal = "0";
my $solved = "1";
my $i = 0;
for (my $idx = 80; $idx >= 0; --$idx) {
  if ( ($i++ % 9) == 0 ) {
    $is_singleton .= "\n    ";
    $solved .= "\n    ";
  }
  $is_singleton .= " | cell_singleton[$idx]";
  $is_illegal .= " | cell_illegal[$idx]";
  $solved .= " & cell_solved[$idx]";
}

print "wire [80:0] cell_singleton;\n";
print "assign is_singleton = $is_singleton;\n";
print "wire [80:0] cell_illegal;\n";
print "assign is_illegal = $is_illegal;\n";
print "wire [80:0] cell_solved;\n";
print "assign solved = $solved;\n";

print "wire [80:0] rdata_cell [0:8];\n";

my @rowids;
my @colids;
my @boxids; 
for (my $row = 0; $row < 9; ++$row) {
  my $row3 = int($row/3);
  for (my $col = 0; $col < 9; ++$col) {
      my $col3 = int($col/3);
      my $idx = $row*9+$col;
      my $box = $row3*3+$col3;
      push @{ $rowids[$row] }, $idx;
      push @{ $colids[$col] }, $idx;
      push @{ $boxids[$box] }, $idx;
      print "sudoku_cell cell$row$col( .clk(clk), .reset(reset),\n".
        "  .rdata(rdata_cell[$row][" . (9*($col+1)-1) .":" . 9*$col . "]), .wdata(wdata_c[" . (9*($col+1)-1) .":" . 9*$col . "]),\n".
        "  .address(cell_addr), .we(row_en_c[$row] & we_c[$col3]),\n". # .oe(row_en_c[$row] & oe_c),\n".
        "  .latch_singleton(latch_singleton),\n".
        "  .is_singleton(cell_singleton[$idx]), .is_illegal(cell_illegal[$idx]), .solved(cell_solved[$idx]) );\n";
  }
}

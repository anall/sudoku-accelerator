#!/usr/bin/perl
use v5.10;
use strict;
use warnings;

print "// This garbage generated using tools/generate_cells.pl\n";
my $is_singleton = "0";
my $solved = "1";
my $i = 0;
for (my $idx = 80; $idx >= 0; --$idx) {
  if ( ($i++ % 9) == 0 ) {
    $is_singleton .= "\n    ";
    $solved .= "\n    ";
  }
  $is_singleton .= " | cell_singleton[$idx]";
  $solved .= " & cell_solved[$idx]";
}
print "assign is_singleton = $is_singleton;\n";
print "assign solved = $solved;\n";

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
      print "sudoku_cell cell$row$col( .clk(clk), .reset(reset), .value_io(data_i[" . (9*($col+1)-1) .":" . 9*$col . "]),\n".
        "  .address(cell_addr), .we(row_en_c[$row] & we_c[$col3]), .oe(row_en_c[$row] & oe_c),\n".
        "  .latch_valid(row_en_c[$row] & latch_valid), .latch_singleton(latch_singleton),\n".
        "  .is_singleton(cell_singleton[$idx]), .solved(cell_solved[$idx]) );\n";
  }
}

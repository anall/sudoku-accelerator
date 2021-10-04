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
      print "sudoku_cell cell$row$col( .clk(clk), .reset(reset), .value_io(data[" . (9*($col+1)-1) .":" . 9*$col . "]),\n".
        "  .address(cell_addr), .we(row_e[$row] & we_nb[$col3]), .oe(row_e[$row] & oe),\n".
        "  .latch_valid(latch_valid), .latch_singleton(latch_singleton), .value(values[$idx]),\n".
        "  .valid_row(valid_row[$row]), .valid_col(valid_col[$col]), .valid_box(valid_box[$box]),\n".
        "  .is_singleton(cell_singleton[$idx]), .solved(cell_solved[$idx]) );\n";
  }
}

for (my $i = 0; $i < 9; ++$i) {
  print "assign valid_row[$i] = " . join(' & ', map { "~values[$_]" } @{$rowids[$i]}) . ";\n";
  print "assign valid_col[$i] = " . join(' & ', map { "~values[$_]" } @{$colids[$i]}) . ";\n";
  print "assign valid_box[$i] = " . join(' & ', map { "~values[$_]" } @{$boxids[$i]}) . ";\n";
}

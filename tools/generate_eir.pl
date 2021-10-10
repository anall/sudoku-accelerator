#!/usr/bin/perl
# SPDX-FileCopyrightText: 2021 Andrea Nall
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0
use v5.10;
use strict;
use warnings;

my $pre = "          ";
print "$pre// Following generated using tools/generate_eir.pl\n";
my @box;
my @row;
for (my $c = 0; $c < 9; ++$c) {
  my $end = 9*($c+1)-1;
  my $start = 9*($c);
  my $cell = "~rdata_c[$end:$start]";
  print $pre . "valid_col[$c] <= (row_en_i==1?9'b111111111:valid_col[$c]) & $cell;\n";
  push @box, $cell;
  push @row, $cell;
  if ( $c == 2 || $c == 5 || $c == 8 ) {
    my $bid = int($c/3);
    print $pre . "valid_box[$bid] <= (clear_box?9'b111111111:valid_box[$bid]) & " . join('&',@box) . ";\n";
    @box = ();
  }
}

my $row = join('&',@row);
for (my $c = 0; $c < 9; ++$c) {
  print $pre . "wdata_i[" . (9*($c+1)-1) . ":" . (9*$c) . "] <= $row;\n";
}
print "$pre// END generated block\n";

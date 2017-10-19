#!/usr/bin/env perl
use strict;
use warnings;
use Time::Piece;

# Usage:  strace -tt -T someprog... > out.strace &&
#    strace-tt-to-count.pl out.strace > out.points &&
#    gnuplot -p -e "plot \"out.points\""

my ($i, $first_tp, $cur_sec, $last_hms);
while (<>) {
  my ($hms, $ms) = m{^(\d\d:\d\d:\d\d)(\.[\d\.]+)}
    or next;

  if (not $first_tp) {
    $first_tp = Time::Piece->strptime($hms, q{%H:%M:%S});
    $cur_sec = 0;
  } elsif ($last_hms and $last_hms ne $hms) {
    $cur_sec = Time::Piece->strptime($hms, q{%H:%M:%S}) - $first_tp;
  }

  print "$cur_sec$ms", qq|\t|, ++$i, "\n";

  $last_hms = $hms;
}

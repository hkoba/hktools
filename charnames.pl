#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;

use open IO => ":locale";

require charnames;

while (<>) {
  chomp;
  foreach my $c (split //) {
    if ($c =~ /^[\ \t\n]$/) {
      print "\n"; next;
    }
    printf "%s\t\\x{%x}\t%s\n", $c, ord($c), charnames::viacode(ord($c));
  }
}

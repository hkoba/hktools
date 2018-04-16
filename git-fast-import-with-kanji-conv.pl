#!/usr/bin/env perl
use strict;
use Jcode;

my $last_pos;
while (<>) {
  if (my ($origBytes) = /^data (\d+)/ and $1) {
    unless (read(ARGV, $_, $origBytes)) {
      die $!;
    }
    $_ = Jcode->new($_)->utf8;
    my $newBytes = length($_);
    print "data $newBytes\n";
    print STDERR "Changed data at $. ($origBytes => $newBytes)";
  }
  print;
} continue {
  $last_pos = tell ARGV;
}



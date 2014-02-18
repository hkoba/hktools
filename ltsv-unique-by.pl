#!/usr/bin/perl -w
use strict;
use warnings FATAL => qw/all/;

{
  my (@cols);
  while (@ARGV and $ARGV[0] =~ m{^\+(\S+)}) {
    push @cols, $1;
    shift;
  }

  @cols or usage();

  my %dups;
  while (<>) {
    chomp;
    my %log = map {split ":", $_, 2} split "\t";
    next if grep {$dups{$_}{$log{$_}}++} @cols;
    print "$_\n";
  }
}

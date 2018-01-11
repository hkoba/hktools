#!/usr/bin/env perl
# -*- coding: utf-8 -*-
use strict;
use warnings FATAL => qw/all/;

{
  my @lines;
  while (<>) {
    s/^\xef\xbb\xbf// if $. == 1; # Trim BOM
    chomp;
    s/\r//;
    my $c = 0;
    foreach my $col (split "\t", $_, -1) {
      $lines[$c][$. - 1] = $col;
    } continue {
      $c++;
    }
    if (eof) {
      foreach my $line (@lines) {
        print join("\t", map {$_ // ''} @$line), "\n"; # XXX: CRLF?
      }
      close ARGV;
    }
  }
}

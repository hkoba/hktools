#!/usr/bin/env perl
use strict;
use warnings;
use Crypt::HSXKPasswd::Dictionary::EN;

# Crypt::HSXKPasswd itself is too much.

{
  my ($min_length) = shift || 32;

  my @words = @{Crypt::HSXKPasswd::Dictionary::EN::word_list()};
  my $len = 0;
  while (1) {
    my $w = splice @words, rand(@words), 1;
    print $w, " ";
    $len += length $w;
    last if $len >= $min_length;
  }
  print "#$len\n";
}

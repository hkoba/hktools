#!/usr/bin/env perl
use strict;
use warnings;

# Collect [GH #NN] lines and format them for Changes.
# (Hand editing is required, though.)

# Use this like following:
# git log 1.00..1.01 | git-log-collect-gh-issues.pl
#

{
  my %issues;
  while (<>) {
    chomp;
    m{\[GH \#(\d+)\]} or next;
    push @{$issues{$1}}, $_;
  }

  my $indent = "        ";

  print map {
    "$indent - [GH #$_]". join("\n$indent   ", @{$issues{$_}}). " \n"
  } sort {$b <=> $a} keys %issues;
}

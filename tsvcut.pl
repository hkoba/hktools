#!/usr/bin/env perl
# -*- coding: utf-8 -*-
use strict;
use warnings FATAL => qw/all/;
use autodie;

{
  my %watchColNames;
  while (@ARGV and $ARGV[0] =~ /^[\+\@](.*)$/) {
    $watchColNames{$1}++;
    shift @ARGV;
  }
  unless (keys %watchColNames) {
    die "Please specifly column name!\n";
  }
  foreach my $fn (@ARGV) {
    local $/ = "\r\n";
    open my $fh, '<', $fn;
    defined(my $header = <$fh>)
      or do { warn "Can't read header from $fn\n"; next };
    my @header = split "\t", $header;
    my %found;
    my @watchCols = map {
      if ($watchColNames{$header[$_]}) {
	$found{$header[$_]}++;
	$_;
      } else {
	();
      }
    } 0 .. $#header;

    unless (keys %found == keys %watchColNames) {
      die "Can't find column: "
	.join(" ", grep {not $found{$_}} sort keys %watchColNames);
    }

    print tsv(@header[@watchCols]), "\r\n";

    while (my $line = <$fh>) {
      my @cols = split "\t", $line;
      print tsv(@cols[@watchCols]), "\r\n";
    }
  }
}

sub tsv {
  join "\t", map {$_ // ''} @_;
}

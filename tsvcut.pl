#!/usr/bin/env perl
# -*- coding: utf-8 -*-
use strict;
use warnings FATAL => qw/all/;
use autodie;
use Getopt::Long;

{
  GetOptions("u|unix" => \ (my $o_unix = 0))
    or usage();

  my (%watchColNames, @watchColList);
  while (@ARGV and $ARGV[0] =~ /^\@(.*)$/) {
    $watchColNames{$1}++;
    push @watchColList, $1;
    shift @ARGV;
  }
  unless (keys %watchColNames) {
    die "Please specifly column name!\n";
  }

  unshift @ARGV, '-' unless @ARGV;

  local ($/, $\) = map {$_, $_} $o_unix ? "\n" : "\r\n";

  foreach my $fn (@ARGV) {
    my $fh;
    if ($fn eq '-') {
      $fh = \*STDIN;
    } else {
      open $fh, '<', $fn;
    }
    defined(my $header = <$fh>)
      or do { warn "Can't read header from $fn\n"; next };
    $header =~ s/^\xef\xbb\xbf//; # Trim BOM
    if ($o_unix and $header =~ /\r$/) {
      warn "Input ends with CRLF!";
    }
    my @header = split "\t", $header;
    my @watchCols = do {
      my %found;
      foreach (0 .. $#header) {
	defined $watchColNames{$header[$_]}
	  or next;
	$found{$header[$_]} = $_;
      }

      unless (keys %found == keys %watchColNames) {
	die "Can't find column: "
	  .join(" ", grep {not $found{$_}} sort keys %watchColNames);
      }

      map {$found{$_}} @watchColList;
    };

    print tsv(@header[@watchCols]);

    while (my $line = <$fh>) {
      my @cols = split "\t", $line;
      print tsv(@cols[@watchCols]);
    }
  }
}

sub tsv {
  join "\t", map {$_ // ''} @_;
}

sub usage {
  die <<END;
Usage: $0 [-u] file...
END
}

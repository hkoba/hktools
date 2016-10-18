#!/usr/bin/perl
use strict;
use warnings FATAL => qw/all/;
use autodie;
use File::Basename;

sub tsv (@);
sub usage {
  die <<END;
Usage: @{[basename($0)]} [-N | +N] TSV_FILE...
Merge TSV_FILEs by -N-th column value.
- Default merge column is -1 (last column).
- Each TSV_FILE must have header line.
END
}

{
  usage() unless @ARGV;

  my $join_col = -1;
  my %all;
  my @header;
  my $fileno = -1;
  while (@ARGV) {
    my $arg = shift @ARGV;

    # Set $join_col when [-N | +N] is given.
    if ($arg =~ /^([-+]\d+)$/) {
      $join_col = $1;
      next;
    }

    $fileno++;
    my $fn = $arg;
    open my $fh, "<", $fn;
    local $_;
    push @header, do {
      chomp(my $line = <$fh>);
      [split "\t", $line];
    };
    while (<$fh>) {
      chomp;
      my $tsv = [split "\t", $_];
      $all{$tsv->[$join_col]}[$fileno] = $tsv;
    }
  }

  print tsv(map {@$_} @header);

  foreach my $key (sort keys %all) {
    my $item = $all{$key};
    print tsv map {
      if ($item->[$_]) {
        @{$item->[$_]}
      } else {
        ('') x (@{$header[$_]})
      }
    } 0 .. $#$item;
  }
}

sub tsv (@) {
  join("\t", map {$_ // ''} @_)."\n";
}

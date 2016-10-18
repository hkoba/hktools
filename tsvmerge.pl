#!/usr/bin/perl
use strict;
use warnings FATAL => qw/all/;
use autodie;

sub tsv (@);
{
  my %all;
  my @header;
  my $fileno = 0;
  foreach my $fn (@ARGV) {
    open my $fh, "<", $fn;
    local $_;
    push @header, do {
      chomp(my $line = <$fh>);
      [split "\t", $line];
    };
    while (<$fh>) {
      chomp;
      my $tsv = [split "\t", $_];
      $all{$tsv->[-1]}[$fileno] = $tsv;
    }
  } continue {
    $fileno++;
  }

  print tsv(my @joined_header = map {@$_} @header);

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

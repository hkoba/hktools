#!/usr/bin/env perl
# -*- coding: utf-8 -*-
use strict;
use warnings FATAL => qw/all/;
use Getopt::Long;
use File::Basename;
use autodie;
use Data::Dumper;
use Scalar::Util qw/looks_like_number/;
use Math::Round qw/nearest/;

use fields qw/max_diff/;
sub MY () {__PACKAGE__}

{
  my MY $opts = fields::new(MY);

  GetOptions("m|max-diff=f", \ ($opts->{max_diff} = 0.1))
    or usage();

  @ARGV >= 2 or usage();

  my ($compare_with_dir, @files) = @ARGV;

  foreach my $fn (@files) {
    -r $fn or do {
      warn "Can't read file: $fn. skipped\n"; next;
    };
    my $cmpfn = "$compare_with_dir/$fn";
    -r $cmpfn or do {
      warn "Can't read file: $cmpfn. skipped\n"; next;
    };

    if (my @diff = $opts->tsvdiff($cmpfn, $fn)) {
      print "$fn\t", scalar @diff, "\t", terse_dump(@diff), "\n";
    }
  }
}

sub usage {
  die <<END;
Usage: @{[basename($0)]} [-m 0.1] COMP_DIR FILES...

Compare given files(namely \$F) as TSV with \$COMP_DIR/\$F.

-m NUMBER   Max difference.

END
}

sub tsvdiff {
  (my MY $opts, my ($cmpfn, $fn)) = @_;
  open my $cmpfh, '<', $cmpfn;
  open my $fh, '<', $fn;
  my @diff;
  my ($lineno, $cmptsv, $tsv) = (1);
  for ($cmptsv = read_tsv($cmpfh), $tsv = read_tsv($fh)
       ; $cmptsv && $tsv
       ; $lineno++, $cmptsv = read_tsv($cmpfh), $tsv = read_tsv($fh)) {
    my $cmin = min(scalar @$cmptsv, scalar @$tsv);
    for (my $c = 0; $c < $cmin; $c++) {
      my ($cv, $v) = map {
	s/^(\d+(?:\.\d+)?)[^\d\.].*$/$1/;
	$_;
      } ($cmptsv->[$c], $tsv->[$c]);
      if ($cv eq $v
	  or zero_or_hyphen($cv, $v)) {
	# nop
      } elsif (looks_like_number($cv) and looks_like_number($v)) {
	if ((my $diff = round(abs($cv - $v))) > $opts->{max_diff}) {
	  push @diff, ["<$lineno.$c>", $cv, $v]
	} else {
	  # ok
	}
      } elsif (not looks_like_number($cv) and not looks_like_number($v)) {
	# nop
      } else {
	push @diff, ["<$lineno.$c>", $cv, $v];
      }
    }
  }
  @diff;
}

sub read_tsv {
  my ($fh) = @_;
  local $/ = "\r\n";
  defined(my $line = <$fh>)
    or return;
  chomp($line);
  my @lines = map {
    s/^\"|\"$//g;
    s/(\d),(\d)/$1$2/g;
    $_} split "\t", $line, -1;
  wantarray ? @lines : \@lines;
}

sub min {
  $_[0] < $_[1] ? $_[0] : $_[1];
}

sub terse_dump {
  Data::Dumper->new(\@_)->Terse(1)->Indent(0)->Dump
}

sub round {
  Math::Round::nearest(0.1, $_[0]);
}

sub zero_or_hyphen {
  foreach my $val (@_) {
    return '' if $val ne '-' and $val ne '0' and $val ne '0.0';
  }
  return 1;
}

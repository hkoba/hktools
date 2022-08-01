#!/usr/bin/perl -w
use strict;
use warnings FATAL => qw/all/;

use fields qw/o_noheader/;
sub MY () {__PACKAGE__}

{
  my MY $opts = fields::new(MY);
  my %opt_alias = qw/n o_noheader/;
  my (@headers);
  while (@ARGV and $ARGV[0] =~ m{^-(?<opt>\w+)|^\+(?<key>\S+)}) {
    if (defined $+{key}) {
      push @headers, $+{key};
    } elsif (defined $+{opt}) {
      my $o = $opt_alias{$+{opt}} || $+{opt};
      $opts->{$o} = 1;
    } else {
      die "really?";
    }
    shift;
  }

  if (not @headers) {
    defined($_ = <>)
      or exit;
    chomp;
    my @cols;
    foreach my $cell (split "\t") {
      my ($label, $value) = split ":", $cell, 2;
      push @headers, $label;
      push @cols, $value;
    }
    print tsv(@headers);
    print tsv(@cols);
  }
  elsif (not $opts->{o_noheader}) {
    print tsv(@headers);
  }
  while (<>) {
    chomp;
    my @pairs = map {split ":", $_, 2} split "\t";
    if (@pairs % 2 != 0) {
      warn "Non LTSV input($_), ignored.\n";
      next;
    }
    my %log = @pairs;
    print tsv(@log{@headers});
  }
}

sub usage {
  die <<END;
Usage: $0 +KEY [+KEY...]  LTSV_FILES...
END
}

sub tsv {
  join("\t", map {$_ // ''} @_)."\n";
}

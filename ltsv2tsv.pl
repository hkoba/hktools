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

  @headers or usage();

  print tsv(@headers) unless $opts->{o_noheader};
  while (<>) {
    chomp;
    my %log = map {split ":", $_, 2} split "\t";
    print tsv(@log{@headers});
  }
}

sub usage {
  die <<END;
Usage: $0 +KEY [+KEY...]  LTSV_FILES...
END
}

sub tsv {
  join("\t", @_)."\n";
}

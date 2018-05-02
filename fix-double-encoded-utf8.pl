#!/usr/bin/perl -wn
use strict;
use warnings;
use utf8;
use constant DEBUG => $ENV{DEBUG};

{
  print STDERR "# ", prob_double_encoded($_), " ", $_ if DEBUG;
  if (prob_double_encoded($_) > 0) {
    print double_decode($_);
  } else {
    print $_;
  }
}

sub double_decode {
  my ($corrupted) = @_;
  require Encode;
  my $once = Encode::decode(utf8 => $corrupted);
  Encode::_utf8_off($once);
  Encode::decode(utf8 => $once);
}

sub prob_double_encoded {
  my ($bin) = @_;

  return 0 unless length $bin;

  # 二度 utf8 encode したテキストには↓このパターンが頻出するので
  my $wrongCnt = $bin =~ m{\xc2[\x80-\xa0]}g;
  return 0 unless $wrongCnt;

  require Encode;
  my $ulen = length(Encode::decode(utf8 => $bin));
  ($wrongCnt * 1.0) / $ulen;
}

#!/usr/bin/env perl
use strict;
use warnings;

{
  my $opt_key = 'a';
  if (@ARGV and $ARGV[0] =~ /^-(\w)$/) {
    $opt_key = $1; shift;
  }

  local $/ = "";
  while (<>) {
    /^Network Information:/
      or next;
    chomp;
    my $dict = parse_whois_network_information($_);
    if (defined (my $val = $dict->{$opt_key})) {
      print "$val\n";
      exit;
    }
  }
  exit 1;
}

sub parse_whois_network_information {
  +{
    map {
      if (/^([a-z])\.\s+\[([^]]+)\]\s*(\S.*)?/) {
	($1 => $3);
      } else {
	();
      }
    } split /\n/, $_[0]
  };
}

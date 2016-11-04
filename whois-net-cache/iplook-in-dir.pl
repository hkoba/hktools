#!/usr/bin/env perl
use strict;
use warnings;

use Net::IP;

sub usage {
  die <<END;
Usage: $0 DIR IP
END
}

{
  @ARGV == 2 or usage();

  my ($dir, $ipstr) = @ARGV;

  my $ip = Net::IP->new($ipstr);

  foreach my $cand (find_glob($dir, $ip->hexip)) {
    my $fn = substr($cand, length("$dir/"));
    my ($firstHex, $lastHex, $ext) = $fn =~ m{^([\da-f]+)-([\da-f]+)(\..*)}
      or next;
    if (hex($firstHex) <= $ip->intip and $ip->intip <= hex($lastHex)) {
      print "$dir/$fn\n";
      exit;
    }
  }

  exit 1;
}

sub find_glob {
  my ($dir, $hexip, $initLen) = @_;

  $initLen //= 6;
  for (my $i = $initLen; $i >= 4; $i--) {
    my $prefix = substr($hexip, 2, $i);
    my @cand = glob("$dir/$prefix*")
      or next;
    return @cand;
  }
  return;
}

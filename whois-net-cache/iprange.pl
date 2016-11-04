#!/usr/bin/env perl
use strict;
use warnings;

use Net::IP;
use Getopt::Long;

{
  foreach my $addr (@ARGV) {
    my $ip = Net::IP->new($addr)
      or die "Invalid ip addr: $addr\n";
    my $last_ip = Net::IP->new($ip->last_ip);
    print sprintf("%x-%x", map {hex($_->hexip)} $ip, $last_ip), "\n";
  }
}

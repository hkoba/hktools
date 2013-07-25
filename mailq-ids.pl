#!/usr/bin/env perl
#
# mailq | mailq-ids.pl | postsuper -d 
#
use strict;
use warnings FATAL => qw/all/;
local $/ = "";

while (<>) {
  s/^-[^\n]+\n//s;
  /^([\dA-F]+)\s+/ and print "$1\n";
}

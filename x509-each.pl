#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;

#
# x509-each.pl - dump all part of concatenated x509.
#

my @lines;
while (<>) {
  my $line = /^-----BEGIN/ .. /^-----END/ or next;
  push @lines, $_;
  if ($line =~ /E0/) {
    open my $pipe, "|-", qw|openssl x509 -in /dev/fd/0 -noout -text|
      or die "Cant open pipe: $!";
    print $pipe $_ for @lines;
    undef @lines;
  }
}

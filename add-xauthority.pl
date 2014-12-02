#!/usr/bin/perl -w
use strict;

my $key = join "", map {sprintf "%x", int(rand(16))} 1..32;
my $display = $ENV{DISPLAY}
  or die "DISPLAY is empty\n";

my $auth = $ENV{XAUTHORITY}
  or die "XAUTHORITY is empty\n";

my $proto = "MIT-MAGIC-COOKIE-1";

if (-r $auth) {
  system(xauth => add => $display => $proto, $key) == 0
    or die "xauth add failed: $?\n";
} else {
  system(xauth => generate => $display => $proto, data => $key) == 0
    or die "xauth generate failed: $?\n";
}

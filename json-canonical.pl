#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;
use open IO => ':locale', ':std';
use JSON;

{
  local $/;
  while (<>) {
    my $obj = JSON->new->decode($_);
    print JSON->new->canonical(1)->pretty(1)->encode($obj);
  }
}

#!/usr/bin/env perl
# -*- coding: utf-8 -*-
use strict;
use warnings FATAL => qw/all/;

{
  chomp(my $line = <>);
  my $i = 0;
  print map($i++."\t".$_."\n", split "\t", $line);
}

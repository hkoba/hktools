#!/usr/bin/env perl
use strict;
use warnings;

# In short:
# perl -pe 's/^dmi:.*?:svn/dmi:*svn/; s/(:pn[^:]+:).*/$1/;'  /sys/class/dmi/id/modalias
#

@ARGV = qw(/sys/class/dmi/id/modalias) unless @ARGV;

while (<>) {
    s/^dmi:.*?:svn/dmi:*svn/; 
    s/(:pn[^:]+:).*/$1*/;
    print;
}

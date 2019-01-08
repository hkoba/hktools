#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;

use Getopt::Long;

sub Opts () {__PACKAGE__}
use fields qw/inner_path_only/;

sub usage {
  die join("\n\n", @_, <<END);
Usage: @{[basename $0]} /SAMPLE/URL/-/LIKE/THIS
END
}

{
  my Opts $opts;
  GetOptions("inner_path_only" => \$opts->{inner_path_only})
    or usage();

  my $sample_url = shift
    or usage();

  my ($appPrefix, $innerPath) = $sample_url =~ m{^(.*?)/-(/.*)$}s
    or usage("Sample URL must contain '/-/'!");

  my @els = split m{([^/]+)}, $innerPath;
  my $i = 0;
  my $re = "(?<s$i>".shift(@els).")";
  while (@els) {
    shift @els;
    my $word = q{\w+};
    $re = "(?<w$i>$re(?:$word)?)";
    my $slash = shift @els or next;
    $re = "(?<s$i>$re(?:$slash)?)";
  } continue {
    $i++;
  }

  print $re, "\n";
}

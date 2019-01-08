#!/usr/bin/env perl
package SlashBar;
use strict;
use File::AddInc;
use MOP4Import::Base::CLI_JSON -as_base;

sub parse_sample_url {
  (my MY $self, my $sample_url) = @_;

  unless ($sample_url) {
    $self->cmd_help("Not enough argument! parse_sample_url /SAMPLE/URL/-/LIKE/THIS\n");
  }

  my ($appPrefix, $innerPath) = $sample_url =~ m{^(.*?)/-(/.*)$}s
    or $self->cmd_help("Sample URL must contain '/-/'!");

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
  $re;
}

MY->run(\@ARGV) unless caller;

1;

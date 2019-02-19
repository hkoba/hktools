#!/usr/bin/env perl
package SlashBar;
use strict;
use File::AddInc;
use MOP4Import::Base::CLI_JSON -as_base
  , [fields =>
       , [location_prefix => default => ""
          , doc => "Leading portion of local URI"]
   ];

sub parse_sample_url {
  (my MY $self, my $sample_url) = @_;

  unless ($sample_url) {
    $self->cmd_help("Not enough argument! parse_sample_url /SAMPLE/URL/-/LIKE/THIS\n");
  }

  my ($appPrefix, $innerPath) = $sample_url =~ m{^(.*?)/-(/.*)$}s
    or $self->cmd_help("Sample URL must contain '/-/'!");

  my @els = split m{([^/]+)}, $innerPath;

  ($appPrefix, @els);
}

sub regexp_for_sample_url {
  (my MY $self, my $sample_url) = @_;

  unless ($sample_url) {
    $self->cmd_help("Not enough argument! regexp_for_sample_url /SAMPLE/URL/-/LIKE/THIS\n");
  }

  my ($appPrefix, @els) = $self->parse_sample_url($sample_url);
  my $i = 0;
  my $re = "(?<s$i>".shift(@els).")";
  my @vars = ("s$i");
  while (@els) {
    ++$i;
    shift @els;
    my $word = q{\w+};
    $re .= "(?<w$i>$word)?";
    push @vars, "w$i";
    my $slash = shift @els or next;
    $re .= "(?<s$i>$slash)?";
    push @vars, "s$i";
  }

  my $prefixRe = $self->{location_prefix}.q{(?<appPrefix>(?:/[^-\./]+)*)};
  ([$prefixRe, "/-", $re, q{(?<rest>/.*)?}], \@vars);
}

MY->run(\@ARGV) unless caller;

1;

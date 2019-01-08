#!/usr/bin/env perl
package SlashBar;
use strict;
use File::AddInc;
use MOP4Import::Base::CLI_JSON -as_base
  , [fields =>
       , [explicit_app_prefix => doc => "generate regexp with hardcoded app_prefix"]
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
    shift @els;
    my $word = q{\w+};
    $re = "(?<w$i>$re(?:$word)?)";
    push @vars, "w$i";
    my $slash = shift @els or next;
    $re = "(?<s$i>$re(?:$slash)?)";
    push @vars, "s$i";
  } continue {
    $i++;
  }

  my $prefixRe = do {
    if ($self->{explicit_app_prefix}) {
      $appPrefix;
    } else {
      q{(?<appPrefix>(?:/[^-\./]+)*)}
    }
  };

  ([$prefixRe, "/-", $re, q{(?<rest>/.*)?}], [reverse @vars]);
}

MY->run(\@ARGV) unless caller;

1;

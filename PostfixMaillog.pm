#!/usr/bin/env perl
#
# This code is heavily inspired from:
# https://github.com/xtetsuji/p5-Mail-Log-Hashnize.git
#
package PostfixMaillog;
use strict;
use warnings;
use MOP4Import::Base::CLI_JSON -as_base
  , [fields => [year => doc => "year of the first given logfile"]];

my %month = (qw(Jan 1 Feb 2 Mar 3 Apr 4 May 5 Jun 6 Jul 7 Aug 8 Sep 9 Oct 10 Nov 11 Dec 12));

my $re_date = qr/[A-Z][a-z][a-z]  ?\d+ \d{2}:\d{2}:\d{2}/;
my $re_host = qr/\S+/;
my $re_line
  = qr{^(?<date>$re_date)
       [ ]
       (?<host>$re_host)
       [ ]
       (?:postfix/(?<service>[-\w]+)|(?<milter>\w+))\[(?<pid>\d+)\]:
       [ ]
       (?:
         (?<queue_id>[0-9A-F]+):\s*(?<following>.*)
       | (?<event>\w+)(?<event_msg>\W.*)
       )
    }x;

use MOP4Import::Types
  (
    Log => [[fields => qw/date host service milter pid
                          queue_id following
                          event event_msg/]],
  );

sub parse {
  (my MY $self, my @files) = @_;
  local @ARGV = @files;
  local $_;
  # my %queue;
  while (<<>>) {
    chomp;
    /$re_line/
      or do {warn "Can't parse: $_\n"; next};
    $self->cli_output([\%+]);
  }
}

MY->cli_run(\@ARGV) unless caller;

1;

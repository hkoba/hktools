#!/usr/bin/env perl
use strict;
use warnings;

#
# This script converts output of strace(1) to ltsv.
#
# Supported strace options (I hope;-) are:
#
# -f       (follow fork)
# -t,-tt   (the time of day (microseconds))
# -T       (The time spent in system call)
#

{
  while (<>) {
    m{^
      (?:(?<pid>\d+)\ )?
      (?:(?<time>[\d:\.]+)\ )?
      (?<syscall>\S.*?)
      (?:
	\ =\ (?<ret>\d+)
	(?:
	  \ <(?<elapsed>[\d\.]+)>
	)?
      )?
      $
   }x or die "Can't parse strace output: $_";

    my @head = map {
      my $v = $+{$_}; defined $v ? "$_:$v" : ();
    } qw/pid time elapsed ret/; # Print in this order.

    print tsv(@head, "syscall:$+{'syscall'}"), "\n";
  }
}

sub tsv {
  join "\t", map {
    s/[\t\n]/ /g;
    $_;
  } @_;
}


#!/usr/bin/env perl
use strict;
use warnings;

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
    } qw/pid time elapsed ret/;

    print tsv(@head, "syscall:$+{'syscall'}"), "\n";
  }
}

sub tsv {
  join "\t", map {
    s/\t/ /g;
    $_;
  } @_;
}


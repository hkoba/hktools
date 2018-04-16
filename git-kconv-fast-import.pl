#!/usr/bin/env perl
use strict;
use Jcode;

use Getopt::Long qw/:config no_ignore_case/;

sub usage {
  die <<END;
Usage: $0  [-H | --history-only] ...FILES...
Convert legacy kanji code to utf8 in git fast-import files.
END

}

GetOptions("H|history-only", \ (my $o_history_only),
           "h|help", \ (my $o_help),
           "d|debug+", \ (my $o_debug = 0),
         )
  or usage();

$o_help and usage();

{
  while (<>) {
    if ($o_history_only) {
      if (my $line = /^commit / .. (my ($origBytes) = /^data (\d+)/)) {
        $_ = read_n_convert($origBytes) if $line =~ /E0$/ and $origBytes;
      }
    } else {
      if (my ($origBytes) = /^data (\d+)/) {
        $_ = read_n_convert($origBytes) if $origBytes;
      }
    }
    print;
  }
}

sub read_n_convert {
  my ($origBytes) = @_;
  my $buf = "";
  unless (read(ARGV, $buf, $origBytes)) {
    die $!;
  }
  my $converted = Jcode->new($buf)->utf8;
  my $newBytes = length($converted);
  print STDERR "# Changed data at $. ($origBytes => $newBytes)\n" if $o_debug;
  if ($o_debug >= 2) {
    print STDERR "-- $_\n" for split /\n/, $converted;
  }
  "data $newBytes\n$converted";
}

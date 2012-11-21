#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;
use File::Basename;
use Getopt::Long;

# perl -le 'rename($_, s{(?<=\#)\d+}{sprintf "%02d", $&}gr) for @ARGV' *

sub usage {
  die <<END;
Usage: @{[basename $0]} [-v | -n | -f FMT] files...

  This will rename the specified files
  by replacing the "#numbering" portion by sprintf,
  usually used to rename "1 - foo#1.ogg" to "01 - foo#01.ogg".

  -v       --verbose
  -q       --quiet
  -o       --overwrite
  -n       --dryrun
  -f FMT   --format=FMT
  -m PAT   --match=PAT
END
}

{
  GetOptions("h|help", \ my $o_help
	     , "n|dryrun", \ my $o_dryrun
	     , "v|verbose", \ my $o_verbose
	     , "q|quiet", \ my $o_quiet
	     , "o|overwrite", \ my $o_overwrite
	     , "f|format=s", \ my $o_fmt
	     , "m|match=s", \ my $o_match
	    )
    or usage;

  usage if $o_help or not @ARGV;

  $o_fmt ||= "%02d";
  my $re = $o_match ? qr{$o_match} : qr{(?:^|(?<=\#))\d+};

  foreach my $fn (@ARGV) {
    local $_ = $fn;
    s{$re}{sprintf $o_fmt, $&}eg;
    if ($_ eq $fn) {
      print "SKIP: $_\n" if $o_verbose;
      next;
    }
    if (-e $_) {
      print "Conflict: $_\n" if $o_verbose;
      next unless $o_overwrite;
    }
    if ($o_dryrun || rename($fn, $_)) {
      print "REN: $fn\t>>\t$_\n" unless $o_quiet;
    } else {
      print STDERR "ERR: $!\t$fn\n";
    }
  }
}

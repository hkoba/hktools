#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Encode qw(from_to find_encoding);
use open ();

sub usage {
  die join("\n", @_, <<END);
Usage: $0 [--to=ENC | --from=ENC]  FILES...
END
}

{
  GetOptions("t|to=s" => \ (my $o_to)
	     , "f|from=s" => \ (my $o_from))
    or usage();

  if (my @missing = grep {not (-r $_ or $_ eq '-')} @ARGV) {
    # To protect <>
    # (Actually I want to switch to <<>> but it is not yet supported in cperl:-<
    usage("Unreadable arguments: @missing");
  }

  if ($o_to and $o_from) {
    usage("--to and --from is exclusive");
  } elsif ($o_to) {
    # Input is utf16le_BOM.
    # So, treat it as a binary, with manual encode handling.
    #

    unless (find_encoding($o_to)) {
      usage("Bad encoding name: $o_to");
    }

    local $/;
    while (<>) {
      s/^\xFF\xFE//;
      from_to($_, "UTF-16LE", $o_to);
      print;
    }
  } elsif ($o_from) {
    # Input is NOT utf16le_BOM.
    # So, we can rely on PerlIO layers.

    unless (find_encoding($o_from)) {
      usage("Bad encoding name: $o_from");
    }

    print "\xFF\xFE";
    'open'->import(':std'
		   , IN => ":encoding($o_from)"
		   , OUT => ":encoding(UTF-16LE)");
    local $/;
    print while <>;
  } else {
    usage("Please specify either --to or --from");
  }
}

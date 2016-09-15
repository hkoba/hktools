#!/usr/bin/perl
use strict;
use warnings;
use utf8;

# XXX: Should we "use open qw/:std :locale/;" here?
# Note: \P{ASCII} works without above too!

use Getopt::Long;

sub usage {
  die <<END;
Usage: $0 [-l | --list] FILES...

This filter substitutes "\$varが〜〜" with "\${var}が〜〜".
Use this like "perl -i.bak $0 files..." to rewrite your files.

Also, you can use "--list" option to list files with such (bad) patterns.

END

}

{
  GetOptions("l|list", \ (my $o_list)
	     , "h|help", \ (my $o_help)
	   )
    or usage();

  usage() if $o_help;

  if ($o_list) {
    while (<>) {
      m{\$[\da-z_]+\P{ASCII}+}i
	or next;
      print $ARGV, "\n";
      close ARGV;
    }
  } else {
    while (<>) {
      s{\$([\da-z_]+)(\P{ASCII})}{\${$1}$2}ig;
      print;
    }
  }
}

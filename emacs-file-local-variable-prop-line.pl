#!/usr/bin/env perl
use strict;
use warnings qw/FATAL all NONFATAL misc/;
use File::Basename;

sub usage {
  die <<END;
Usage: @{[basename($0)]}  FILES...
or     @{[basename($0)]} --KEY  FILES...
or     @{[basename($0)]} --KEY=TEST_STRING  FILES...

This command extracts "prop-line" from given FILES.
"prop-line" is meta information, embeded in textfiles,
with surrounding "-*-".

If optional "--KEY" is given, this command extract value part of the key
if it exists.

Also if "--KEY=TEST_STRING" is given and the file's prop-line has
same value, this command prints the filename.

For more information about prop-line, see:
https://www.gnu.org/software/emacs/manual/html_node/emacs/Specifying-File-Variables.html
END

}

{
  usage() unless @ARGV;

  my (%looking, $test_mode);
  while (@ARGV and $ARGV[0] =~ /^--(?:(?<key>[-\w]+)(?:=(?<value>.*))?)\z/) {
    shift @ARGV;
    last if not defined $+{key};
    $test_mode++ if defined $+{value};
    $looking{$+{key}} = [$+{value}];
  }

  my ($nfound);
  while (<>) {
    chomp;
    if (1..2) {
      # prop-line only lives in first or second line.
      if (my ($match) = m{-\*- ([^\n]*)? -\*-}) {
	if (%looking) {
	  foreach my $item (split /\s*;\s*/, $match) {
	    next unless $item =~ /:/;
	    my ($key, $value) = split /: /, $item, 2;
	    if (my $found = $looking{$key}) {
	      if (not defined (my $test = $found->[0])) {
		print $value, "\n";
	      } elsif ($test eq $value) {
		print $ARGV, "\n";
		$nfound++;
		last;
	      }
	    }
	  }
	} else {
	  print $match, "\n";
	}
	close ARGV;
      }
    } else {
      close ARGV;
    }
  }

  if ($test_mode) {
    exit($nfound ? 0 : 1);
  }
}

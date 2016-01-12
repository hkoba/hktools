#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Getopt::Long;

use LWP::UserAgent;
require HTTP::Status;
#use HTTP::Request;

sub usage {
  die <<END;
Usage: $0 [-n | --dryrun] URLSRC

This tiny script fetches contents from a url found in URLSRC
and print it to stdout.

When given url returned "302 Moved Permanently",
this command *UPDATES* URLSRC file
(unless -n option is given).
END

}

{
  GetOptions("n|dryrun" => \ (my $o_dryrun)
	     , "m|maxredirects=i" => \ (my $o_max_redirects = 5)
	   )
    or usage();

  my $urlsrc = shift
    or usage();

  chomp(my $urlStr = do {open my $fh, '<', $urlsrc; local $/; <$fh>});

  my $ua = LWP::UserAgent->new;

  my $response = $ua->get($urlStr);

  {
    my @res = $response->redirects;
    my $new_url;
    while (@res and is_permanent_redirect($res[0])) {
      my $res = shift @res;
      $new_url = $res->header('Location');
    }
    if ($new_url) {
      if ($o_dryrun) {
	print STDERR "# Redirected to URL: $new_url\n";
      } else {
	safe_write_file($urlsrc, "$new_url\n");
      }
    }
  }

  print $response->content;
}

sub is_permanent_redirect {
  my ($response) = @_;
  $response->code == &HTTP::Status::RC_MOVED_PERMANENTLY
}

sub safe_write_file {
  my ($fn, $content) = @_;
  my $tmpFn = "$fn.tmp$$";
  {
    open my $fh, '>', $tmpFn;
    print $fh $content;
  }
  rename($tmpFn, $fn);
}

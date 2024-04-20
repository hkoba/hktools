#!/usr/bin/env perl
use strict;
use warnings;
use sigtrap qw(die normal-signals);
use Symbol 'gensym';
use IPC::Open3;
use IO::Handle;

use Getopt::Long;

sub usage {
  die <<END
Usage: $0 CMD ARGS...
END
}

{
  GetOptions("v|verbose" => \ (my $o_verbose))
    or usage();

  my ($cmd, @args) = @ARGV
    or usage();

  my $pid = open3(
    my $chld_in, my $chld_out, my $chld_err = gensym
    , $cmd, @args
  ) or die "Can't run $cmd @args";

  local @ARGV = "-";
  while (<>) {
    chomp;
    if ($o_verbose) {
      print "# Content-Length: ", length($_), "\n";
    }
    print $chld_in "Content-Length: ", length($_), "\r\n\r\n";
    print $chld_in $_;
    $chld_in->flush;
    print "\n";
    my $response = read_response($chld_out) or do {
      print STDERR "NO response, exiting...\n";
      last;
    };
    print "# ==>\n";
    print $response, "\n";
  }
}

sub read_response {
  my ($in_fh) = @_;
  local $/= "\r\n";
  defined(my $line = <$in_fh>)
    or return;
  defined(scalar <$in_fh>)
    or return;
  chomp($line);
  (undef, my $length) = split ": ", $line, 2;
  my $buf = "";
  read($in_fh, $buf, $length)
    or return;
  $buf;
}

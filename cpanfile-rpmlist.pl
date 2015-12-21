#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;
use Module::CPANfile;

{
  GetOptions("ignore-file=s", \ (my $o_ignore_file))
    or die "Invalid options!";
  my %ignored = map {$_=>1} qw/perl/;
  if ($o_ignore_file) {
    open my $fh, '<', $o_ignore_file or die "Can't open '$o_ignore_file': $!";
    while (my $line = <$fh>) {
      chomp($line);
      $ignored{$line} = 1;
    }
  }
  foreach my $cpanfile (@ARGV) {
      my $req = Module::CPANfile->load($cpanfile)->prereq_specs;
      foreach my $mod (map {map {sort keys %$_} @{$req->{$_}}{qw/requires recommends/}} qw(runtime test)) {
         next if $ignored{$mod};
         print "perl($mod)\n";
      }
  }
}

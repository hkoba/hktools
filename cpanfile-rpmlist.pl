#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;
use Module::CPANfile;

# cpanfile-rpmlist.pl -s --packager='Fedora' ./cpanfile

{
  GetOptions("ignore-file=s", \ (my $o_ignore_file)
             , "s|silent", \ (my $o_silent)
             , "packager=s", \ (my $o_packager)
           )
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
      my $dep = "perl($mod)";
      if ($o_packager) {
        my $pkg = qx(rpm -q --whatprovides --qf '%{PACKAGER}' '$dep');
        if ($? != 0) {
          print STDERR "Not in rpm, skipped: $mod\n" unless $o_silent;
          next;
        }
        if ($pkg !~ /$o_packager/) {
          print STDERR "Packager ($pkg) doesn't match, skipped: $mod\n" unless $o_silent;
          next;
        }
      }
      print "$dep\n";
    }
  }
}

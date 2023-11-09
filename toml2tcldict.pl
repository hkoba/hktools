#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use TOML::Parser;
use JSON;
use Tcl;

{
  GetOptions("D|show-perl-dump" => \ my $o_show_perl_dump)
    or usage();

  my $tcl = new Tcl;
  $tcl->Init;

  my $parser = TOML::Parser->new;

  local $/;
  while (<<>>) {
    my $dict = $parser->parse($_);
    print STDERR Dumper($dict) if $o_show_perl_dump;
    print tcldump($tcl, $dict), "\n";
  }
}

sub tcldump {
  my ($tcl, $obj) = @_;
  if (not defined $obj) {
    ""; # XXX: ok?
  }
  elsif (not ref $obj) {
    $obj;
  }
  elsif (ref $obj eq 'ARRAY') {
    scalar $tcl->invoke(list => map {tcldump($tcl, $_)} @$obj);
  }
  elsif (ref $obj eq 'HASH') {
    scalar $tcl->invoke(dict => create => map {
      ($_, tcldump($tcl, $obj->{$_}))
    } sort keys %$obj);
  }
  elsif (JSON::is_bool($obj)) {
    $obj ? "true" : "false";
  }
  else {
    die "Unknown type: $obj";
  }
}

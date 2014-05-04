#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;
use autodie;

use Markdent::Parser;
use Markdent::Handler::MinimalTree;
use Data::Dumper;

sub usage {
  die <<EOF;
Usage: $0 FILE.md
EOF
}

{
  my ($fn) = @ARGV
    or usage();

  my $text = read_file_utf8($fn);
  my $handler = Markdent::Handler::MinimalTree->new;
  my $md = Markdent::Parser->new(handler => $handler, dialect => "GitHub");
  $md->parse({markdown => $text});
  print Dumper($handler->tree);
}

sub read_file_utf8 {
  my ($fn) = @_;
  open my $fh, '<:encoding(utf-8)', $fn;
  my $text = do {local $/; <$fh>};
}

#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use autodie;

use File::Basename;
use Excel::Writer::XLSX;
use File::BOM;

{
  my ($from, $to) = @ARGV;
  $to ||= $from =~ s/\.\w+\z/.xlsx/r;
  my $book = Excel::Writer::XLSX->new($to);
  my $sheet = $book->add_worksheet(rootname(basename($from)));
  my $format = $book->add_format(num_format => '@');
  open my $fh, "<:via(File::BOM)", $from;
  local $_;
  my $rowNo = 0;
  while (<$fh>) {
    chomp;
    my @cols = split "\t", $_, -1;
    for (my $c = 0; $c < @cols; $c++) {
      $sheet->write_string($rowNo, $c, $cols[$c], $format);
    }
  } continue {
    $rowNo++;
  }
}


sub rootname {
  my ($fn) = @_;
  $fn =~ s/\.\w+\z//r;
}

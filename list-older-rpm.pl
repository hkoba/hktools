#!/usr/bin/perl -w
use strict;

sub usage {
  die <<END;
Usage: $0 *.rpm

Compares given rpms w.r.t VERSION/RELEASE and list up older (obsoleted) ones.
END
}

@ARGV or usage();

my $format = <<'END';
%{NAME}\t%{VERSION}\t%{RELEASE}\t%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}.rpm
END

open PIPE, '-|' or exec "rpm", "-qp", "--qf" => $format, @ARGV;

use constant VERSION => 0;
use constant RELEASE => 1;
use constant FILE => 2;

sub vercomp {
  my (@a) = split /(\D+)/, $_[0];
  my (@b) = split /(\D+)/, $_[1];
  my $state;
  for (my $i = 0; $i < @a and $i < @b;) {
    # even
    return $state unless ($state = ($a[$i]||0) <=> ($b[$i]||0)) == 0;
    $i++; last unless $i < @a and $i < @b;

    # odd
    return $state unless ($state = $a[$i] cmp $b[$i]) == 0;
    $i++;
  }
  @a <=> @b;
}

my %dict;
while (<PIPE>) {
  chomp;
  my ($name, $version, $release, $file) = split /\t/, $_, 4;
  if (not defined $dict{$name}) {
    $dict{$name} = [$version, $release, $file];
  } else {
    printf "version(%s) %s %s\n", $name, $dict{$name}->[VERSION], $version
      if $ENV{VERBOSE};
    if (vercomp($dict{$name}->[VERSION], $version) < 0) {
      print $dict{$name}->[FILE], "\n";
      $dict{$name} = [$version, $release, $file];
      next;
    }
    printf "release(%s) %s %s\n", $name, $dict{$name}->[RELEASE], $release
      if $ENV{VERBOSE};
    if (vercomp($dict{$name}->[RELEASE], $release) <= 0) {
      print $dict{$name}->[FILE], "\n";
      $dict{$name} = [$version, $release, $file];
    }
  }
}

#!/usr/bin/env perl
package HashJoin;
use strict;
use MOP4Import::Base::CLI_JSON -as_base
  , [fields =>
     [join => doc => "Use this field as a join key(default: 1)(starting 1)"
      , default => 1, no_getter => 1],
     [separator => doc => "field separator(default: <TAB>)"
      , default => "\t"],
   ];

sub cmd_join_tsv {
  (my MY $self, my (@files)) = @_;
  unless (@files) {
    die "Usage: $0 join_tsv FILE1 FILE2...\n";
  }

  my ($baseFn, @other) = @files;

  my (@base, %base);
  my $baseProps = 0;
  {
    local @ARGV = $baseFn;
    local ($_, $.);
    while (<<>>) {
      chomp; s/\r$//;
      my (@tsv) = split $self->{separator};
      $baseProps = max($baseProps, @tsv - 1);
      my $pk = $tsv[$self->{join} - 1];
      unless (defined $pk) {
        warn "FIELD $self->{join} is undef at line $. file $baseFn, ignored";
        next;
      }
      if (defined $base{$pk}) {
        warn "duplicate key $pk found at line $. file $baseFn, ignored";
        next;
      }
      push @base, \@tsv;
      $base{$pk} = \@tsv;
    }
  }

  my $totalProps = $baseProps;
  foreach my $otherFn (@other) {
    local @ARGV = ($otherFn);
    my @delayed;
    my $thisProps = 0;
    while (<<>>) {
      chomp; s/\r$//;
      my (@tsv) = split $self->{separator};
      $thisProps = max($thisProps, @tsv - 1);
      my $pk = $tsv[$self->{join} - 1];
      unless (defined $pk) {
        warn "FIELD $self->{join} is undef at line $. file $baseFn, ignored";
        next;
      }
      if (defined $base{$pk}) {
        splice @tsv, $self->{join} - 1, 1;
        push @{$base{$pk}}, @tsv
      } else {
        push @delayed, \@tsv;
      }
    }
    if (@delayed) {
      foreach my $tsv (@delayed) {
        my $pk = $tsv->[$self->{join} - 1];
        splice @$tsv, $self->{join} - 1, 1;
        my @new = ($pk, ("") x $totalProps, @$tsv);
        push @base, \@new;
        $base{$pk} = \@new;
      }
    }

    $totalProps += $thisProps;
  }

  print join("\t", @$_), "\n" for @base;
}

sub max { $_[0] < $_[1] ? $_[1] : $_[0] }


MY->cli_run(\@ARGV) unless caller;
1;

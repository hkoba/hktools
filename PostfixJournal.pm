#!/usr/bin/env perl
package PostfixJournal;
use strict;
use warnings;
use MOP4Import::Base::CLI_JSON -as_base;

use MOP4Import::Types
  (Journal => [[fields =>
                  qw/
                     MESSAGE
                     _SOURCE_REALTIME_TIMESTAMP
                     /]],
   Entry => [[fields =>
                qw/
                   from to relay delay delays dsn status
                   uid message-id
                   size nrcpt
                   /
                     ]]);

use JSON;

sub parse {
  (my MY $self, my @fn) = @_;
  local @ARGV = @fn;
  local $_;
  my %queue;
  while (<>) {
    my Journal $log = decode_json($_);
    my $msg = $log->{MESSAGE};
    if (my ($queue_id) = $msg =~ s/^([0-9A-F]+): //) {
      my Entry $entry = $queue{$queue_id} //= +{};
      my @items = do {
        if ($msg =~ /^uid=/) {
          map {[split /=/, $_, 2]} split " ", $msg;
        } else {
          map {[split /=/, $_, 2]} split /,\s*/, $msg;
        }
      };
      foreach my $item (@items) {
        $entry->{$item->[0]} = $item->[1];
      }
    }
  }
  \%queue;
}

MY->run(\@ARGV) unless caller;

1;

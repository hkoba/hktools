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
                   client
                   from to relay delay delays dsn status
                   uid message-id
                   size nrcpt
                   info

                   status_timestamp
                   /
                     ]]);

use JSON ();

sub parse {
  (my MY $self, my @fn) = @_;
  local @ARGV = @fn;
  local $_;
  my %queue;
  while (<>) {
    my Journal $log = JSON::decode_json($_);
    my ($queue_id, @kvitems) = $self->decode_log($log)
      or next;
    my $entry = $queue{$queue_id} //= +{};
    foreach my $item (@kvitems) {
      $entry->{$item->[0]} = $item->[1];
      if ($item->[0] eq 'status') {
        if ($entry->{status} =~ s/\s*\((.+)\)\z//) {
          $entry->{info} = $1;
          $entry->{status_timestamp} =
            ($log->{_SOURCE_REALTIME_TIMESTAMP} * 0.000001);
        }
      }
    }
  }
  \%queue;
}

sub decode_log {
  (my MY $self, my Journal $log) = @_;

  my $msg = $log->{MESSAGE};

  $msg =~ s/^([0-9A-F]+): //
    or return;

  my ($queue_id) = $1;

  my @items = do {
    if ($msg =~ /^uid=/) {
      map {[split /=/, $_, 2]} split " ", $msg;
    } else {
      map {[split /=/, $_, 2]} split /,\s*/, $msg;
    }
  };
  ($queue_id, @items);
}

MY->run(\@ARGV) unless caller;

1;

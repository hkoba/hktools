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
                   _queue_id
                   client
                   from
                   uid message-id
                   size nrcpt

                   _recipient
                   _first_timestamp
                   /
           ]],
   Recipient => [[fields =>
                    qw/
                       to relay delay delays dsn status
                       _info
                       _status_timestamp
                       /
                     ]],
 );

use JSON ();

sub parse {
  (my MY $self, my @fn) = @_;
  local @ARGV = @fn;
  local $_;
  my %queue;
  while (<>) {
    my Journal $log = JSON::decode_json($_);
    my ($queue_id, $kvitems, $info) = $self->decode_message($log->{MESSAGE})
      or next;
    my Entry $entry = $queue{$queue_id} //= +{
      # XXX: ここで型宣言が活かせなくて悔しい
      _queue_id => $queue_id,
      _first_timestamp => $self->log_timestamp($log),
    };
    if ($kvitems->[0][0] eq 'to') {
      push @{$entry->{_recipient}}, my Recipient $recpt = +{};
      $recpt->{$_->[0]} = $_->[1] for @$kvitems;

      $recpt->{_info} = $info;
      $recpt->{_status_timestamp} = $self->log_timestamp($log);
    } else {
      $entry->{$_->[0]} = $_->[1] for @$kvitems;
    }
  }

  sort {
    # XXX: ここで型宣言が使えなくて悔しい
    $a->{_first_timestamp} <=> $b->{_first_timestamp}
  } values %queue;
}

sub log_timestamp {
  (my MY $self, my Journal $log) = @_;
  $log->{_SOURCE_REALTIME_TIMESTAMP} * 0.000001;
}

sub decode_message {
  (my MY $self, my $msg) = @_;

  $msg =~ s/^([0-9A-F]+): //
    or return;

  my ($queue_id) = $1;

  $msg =~ /=/
    or return;

  my $info;
  if ($msg =~ s/\s*\((.+)\)\z//) {
    $info = $1;
  }

  my @items = map {
    /=/ ? [split /=/, $_, 2] : ();
  } do {
    if ($msg =~ /^uid=/) {
      split " ", $msg;
    } else {
      split /,\s*/, $msg;
    }
  };
  ($queue_id, \@items, $info);
}

MY->run(\@ARGV) unless caller;

1;

=head1 NAME

PostfixJournal - parse postfix log from journald json

=head1 SYNOPSIS

  journalctl -u postfix --since 14:58:52 --until 14:58:58 --output json |
  PostfixJournal.pm parse |
  jq .

=head1 SEE ALSO

L<Mail-Log-Hashnize|https://github.com/xtetsuji/p5-Mail-Log-Hashnize.git>

=head1 AUTHOR

hkoba

=cut

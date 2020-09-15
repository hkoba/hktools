#!/usr/bin/env perl
#
# This code is heavily inspired from:
# https://github.com/xtetsuji/p5-Mail-Log-Hashnize.git
#
package PostfixMaillog;
use strict;
use warnings;
use MOP4Import::Base::CLI_JSON -as_base
  , [fields =>
     [year => doc => "year of the first given logfile"],
     qw/
         _prev_mm_dd
       /
   ];

use MOP4Import::Types
  (
    Log => [[fields => qw/date host service milter pid
                          queue_id following
                          event event_msg/]],
    QRec => [[fields => qw/client client_hostname client_ipaddr
                           status
                           information
                           from to
                           uid
                           _meta
                          /]],
    Meta => [[fields => qw/host start_date success end_date/]],
  );

my %month = (qw(Jan 1 Feb 2 Mar 3 Apr 4 May 5 Jun 6 Jul 7 Aug 8 Sep 9 Oct 10 Nov 11 Dec 12));

my $re_date = qr/[A-Z][a-z][a-z]  ?\d+ \d{2}:\d{2}:\d{2}/;
my $re_host = qr/\S+/;
my $re_line
  = qr{^(?<date>$re_date)
       [ ]
       (?<host>$re_host)
       [ ]
       (?:postfix/(?<service>[-\w]+)|(?<milter>\w+))\[(?<pid>\d+)\]:
       [ ]
       (?:
         (?<queue_id>[0-9A-F]+):\s*(?<following>.*)
       | (?<event>\w+)(?<event_msg>\W.*)
       )
    }x;

sub after_configure_default {
  (my MY $self) = @_;
  $self->{year} //= (1900 + [localtime(time)]->[5]);
}

sub parse {
  (my MY $self, my @files) = @_;
  local @ARGV = @files;
  local $_;

  my (%queue);
  while (<<>>) {
    chomp;
    /$re_line/
      or do {warn "Can't parse: $_\n"; next};

    my Log $log = +{%+};

    if ($self->skew_date($log->{date})) {
      $self->{year}++;
    }

    if ($log->{service} and defined $log->{queue_id}) {

      my ($information) = $log->{following} =~ /\s*\((.+)\)$/
        and $log->{following} =~ s/\s\(.+\)$//;

      my QRec $current = $self->parse_following($log->{following}, $information);

      my QRec $merged = $self->merge_hash($queue{$log->{queue_id}} //= +{}
                                          , $current
                                        );

      my Meta $meta = $merged->{_meta} //= +{};

      $meta->{host} //= $log->{host};
      if ($current->{client} || $current->{uid}) {
        $meta->{start_date} //= $self->date_format($log->{date});
      }
      if ($current->{status} and $current->{status} eq 'sent') {
        $meta->{success}++;
        $meta->{end_date} = $self->date_format($log->{date});
      }

      $self->cli_output([[$merged, $log]]);
    }
    else {
      $self->cli_output([$log]);
    }
  }
}

sub merge_hash {
  (my MY $self, my ($q, $hb)) = @_;
  for my $key (keys %$hb) {
    my $value = $hb->{$key};
    if ( !exists $q->{$key} ) {
      # 新規採用 / newly
      $q->{$key} = $value;
    } elsif ( !ref $q->{$key} ) { # 文字列 / string
      # 配列リファレンスにして追加 / Addition as array reference
      $q->{$key} = [$q->{$key}, $value];
    } elsif ( ref $q->{$key} eq 'ARRAY' ) {
      # 配列リファレンスに push / push to array reference
      push @{$q->{$key}}, $value;
    } else {
      die "unknown situation."; # 想定外 / non-supposition
    }
  }

  $q;
}

sub parse_following {
  (my MY $self, my ($following, $information)) = @_;

  my QRec $qrec = +{};

  return $qrec unless $following =~ /=/;

  my @param = map { split /=/, $_, 2 } split /,\s*/, $following;
  if ( @param % 2 == 0 ) {
    %$qrec = @param;
  }
  else {
    warn "found odd number of key/value pair.";
  }

  if ( exists $qrec->{client} && defined $qrec->{client} ) {
    my ($hostname, $ipaddr) = $qrec->{client} =~ /^(.+?)\[([0-9.]+)\]/;
    $qrec->{client_hostname} = $hostname;
    $qrec->{client_ipaddr}   = $ipaddr;
  }
  if ( $information && $qrec->{status} ) {
    $qrec->{information} = $information;
  }
  for my $key ( qw(from to) ) {
    if ( defined $qrec->{$key} && $qrec->{$key} =~ /^<(.*)>$/ ) {
      $qrec->{$key} = $1;
    }
  }

  $qrec;
}

sub date_format {
  (my MY $self, my $date_str) = @_;
  my ($mon_name, $day, $hhmmss) = split /\s+/, $date_str;
  #    my ($hh, $mm, $ss) = map { sprintf '%d', $_ } split /:/, $hhmmss;
  # sprintf に8進数と勘違いされないように
  # We avoid that sprintf confuses it octet.
  $day =~ s/^0//;
  my $mon = $month{$mon_name};
  return sprintf '%d/%02d/%02d %s', $self->{year}, $mon, $day, $hhmmss;
}

sub skew_date {
  (my MY $self, my $date) = @_;

  my $cur_mm_dd = join '/', (split m{/}, $self->date_format($date))[1,2];

  # skew があるとは、前回の日時が記録されていて、
  # なおかつ今回の日時が更に以前へと遡っている状態のこと
  my $is_skew = _boolean_0_1($self->{_prev_mm_dd}
                             && $cur_mm_dd lt $self->{_prev_mm_dd});

  $self->{_prev_mm_dd} = $cur_mm_dd;

  return $is_skew;
}

sub _boolean_0_1 { $_[0] ? 1 : 0 }

MY->cli_run(\@ARGV) unless caller;

1;

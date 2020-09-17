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
    Log => [[fields => qw/date host program service pid
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
       (?:(?<program>\w+) (?:/ (?<service>[-\w]+))?
       ) \[(?<pid>\d+)\]:
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

  while (<<>>) {
    chomp;
    /$re_line/
      or do {warn "Can't parse: $_\n"; next};

    my Log $log = +{%+};

    if ($self->skew_date($log->{date})) {
      $self->{year}++;
    }

    my $acceptor = $self->can("log_accept_$log->{program}")
      or next;

    $acceptor->($self, $log);
  }
}

sub log_accept_postfix {
  (my MY $self, my Log $log) = @_;

  return unless $log->{service} and defined $log->{queue_id};

  my ($information) = $log->{following} =~ /\s*\((.+)\)$/
    and $log->{following} =~ s/\s\(.+\)$//;

  if ($log->{following} =~ s/^(?<key>\w+): (?<val>[^;]+); //) {
    my @other = ($+{key} => $+{val});
    # ここで返るのは QRec じゃない。厳格に行くべきか悩ましい。
    my $unknown = $self->extract_fromtolike_pairs([split " ", $log->{following}], @other);

    $self->cli_output([[unknown => $log->{queue_id}, $unknown]]);
  } else {
    my QRec $current = do {
      if ($log->{following} =~ /^from=<(.*?)>, status=expired, returned to sender$/) {
        +{from => $1, status => 'expired'};
      }
      else {
        $self->parse_following($log->{following}, $information);
      }
    };

    $self->cli_output([[$log->{queue_id}, $current]]);
  }
}

sub parse_following {
  (my MY $self, my ($following, $information)) = @_;

  return +{} unless $following =~ /=/;

  my QRec $qrec = $self->extract_fromtolike_pairs([split /,\s*/, $following]);

  if ( exists $qrec->{client} && defined $qrec->{client} ) {
    my ($hostname, $ipaddr) = $qrec->{client} =~ /^(.+?)\[([0-9.]+)\]/;
    $qrec->{client_hostname} = $hostname;
    $qrec->{client_ipaddr}   = $ipaddr;
  }
  if ( $information && $qrec->{status} ) {
    $qrec->{information} = $information;
  }

  $qrec;
}

sub extract_fromtolike_pairs {
  (my MY $self, my $wordList, my @other) = @_;

  my QRec $qrec = +{};

  my @param = map { split /=/, $_, 2 } @$wordList;
  if ( @param % 2 == 0 ) {
    %$qrec = (@param, @other);
  }
  else {
    warn "found odd number of key/value pair in $_";
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

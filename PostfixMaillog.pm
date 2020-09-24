#!/usr/bin/env perl
#
# This code is heavily inspired from:
#   https://github.com/xtetsuji/p5-Mail-Log-Hashnize.git
#
# Also, some patterns are stolen from logwatch
#   https://sourceforge.net/p/logwatch/git/ci/master/tree/scripts/services/postfix
#
package PostfixMaillog;
use strict;
use warnings FATAL => qw/all/;
use MOP4Import::Base::CLI_JSON -as_base
  , [fields =>
     [year => doc => "year of the first given logfile"],
     qw/
         _prev_mm_dd
         _known_queue_id
       /
   ];

use MOP4Import::Types
  (
    Log => [[fields => qw/date host program service pid
                          queue_id following
                          event event_msg/]],
    QRec => [[fields => qw/client client_hostname client_ipaddr
                           log
                           date queue_id
                           message-id
                           nrcpt
                           status
                           information
                           from to
                           uid
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
       (?:(?<program>[-\w]+) (?:/ (?<service>[-\w]+))?
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
; # ←これを入れないとインデントが狂う…困ったのぅ…

sub sql_schema {
  <<'END';
create table if not exists all_event
(date datetime not null
, queue_id text
, program text
, service text
, pid integer
, data json
);

create table if not exists mailfrom
(date datetime not null
, queue_id text
, message_id text
, "from" text
, nrcpt integer
, size integer
, uid integer
, client text
, client_hostname
, client_ipaddr
);

create index mailfrom_queue_id on mailfrom("queue_id");
create index mailfrom_message_id on mailfrom("message_id");
create index mailfrom_from on mailfrom("from");

create table if not exists delivery
(date datetime not null
, queue_id text
, message_id text
, "to" text
, status text
, orig_to text
, relay text
, delay integer
, delays text
, dsn text
, conn_use integer
, information text
);

create index delivery_queue_id on delivery("queue_id");
create index delivery_message_id on delivery("message_id");
create index delivery_to on delivery("to");


END
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

    $log->{date} = $self->date_format($log->{date});

    if ($self->skew_date($log->{date})) {
      $self->{year}++;
    }

    # spamass-milter とかはここで捨ててしまっている。
    my $acceptor = $self->can("log_accept_$log->{program}")
      or next;

    $acceptor->($self, $log);
  }

  return; # To avoid last $self->cli_output([""])
}
; # ←これを入れないとインデントが狂う…困ったのぅ…
sub fetch_queue_rec {
  (my MY $self, my $queue_id) = @_;
  $self->{_known_queue_id}{$queue_id} //= +{};
}

sub log_accept_postfix {
  (my MY $self, my Log $log) = @_;

  return unless $log->{service} and defined $log->{queue_id};

  my ($information) = $log->{following} =~ /\s*\((.+)\)$/
    and $log->{following} =~ s/\s\(.+\)$//;

  if ($log->{following} =~ s/^(?<key>\w+): (?<val>[^;]+); //) {
    # ex. reject: RCPT from unknown...
    my @other = ($+{key} => $+{val});
    # ここで返るのは QRec じゃない。厳格に行くべきか悩ましい。
    my $unknown = $self->extract_fromtolike_pairs([split " ", $log->{following}], @other);

    $self->cli_output([[_unknown => $log->{service}, $log->{queue_id}, $unknown, $log]]);
  } else {
    my QRec $current = do {
      if ($log->{service} eq "pickup") {
        my ($uid, $from) = $log->{following} =~ m{^uid=(\d+) from=<([^>]*)>} or do {
          warn "Can't parse pickup log: $log->{following}";
          return;
        };
        my QRec $qrec = $self->fetch_queue_rec($log->{queue_id});
        $qrec->{uid} = $uid;
        $qrec->{from} = $from;
        $qrec;
      }
      elsif ($log->{following} =~ /^from=<(.*?)>, status=expired, returned to sender$/) {
        +{from => $1, status => 'expired'};
      }
      elsif ($log->{following} =~ /^host \S*\[\S*\] said: 4\d\d/) {
        return;
      }
      else {
        $self->parse_following($log->{following}, $information);
      }
    };

    $self->cli_output([[service => $log->{service}, $log->{queue_id}, $current, $log]]);
  }
}

sub cli_output {
  (my MY $self, my $list) = @_;
  if ($self->{output} eq "sql" and @$list) {
    my $item = $list->[0];
    (my ($kind, $service, $queue_id), my QRec $current, my Log $log) = @$item;

    if ($current->{'message-id'}) {
      my QRec $qrec = $self->fetch_queue_rec($queue_id);
      $qrec->{'message-id'} = $current->{'message-id'};
      $qrec->{log} = $log;
    }
    if ($current->{client}) {
      my QRec $qrec = $self->fetch_queue_rec($queue_id);
      $qrec->{client} = $current->{client};
      $qrec->{client_hostname} = $current->{client_hostname};
      $qrec->{client_ipaddr} = $current->{client_ipaddr};
    }
    elsif ($kind ne '_unknown'
           and ($current->{to} or $current->{nrcpt})
           and my QRec $qrec = $self->{_known_queue_id}{$queue_id}
         ) {

      $current->{'message-id'} = $qrec->{'message-id'};
      $current->{queue_id} = $log->{queue_id};
      $current->{date} = $log->{date};

      if ($current->{to}) {
        print $self->sql_insert_with_queue_id(delivery => $queue_id, $current), ";\n";
      }
      elsif ($current->{nrcpt}) {
        print $self->sql_insert_with_queue_id(mailfrom => $queue_id, +{
          %$current,
          uid => $qrec->{uid},
          (defined $qrec->{client} ? (
            client => $qrec->{client},
            client_hostname => $qrec->{client_hostname},
            client_ipaddr => $qrec->{client_ipaddr},
          ) : ())
        }), ";\n";
      }
      else {
        die "Not reachable";
      }
    }
    else {
      # Unknown
    }

    {
      delete $log->{queue_id};
      my $date = delete $log->{date};
      print $self->sql_insert_with_queue_id(all_event => $queue_id, +{
        date => $date, data => $self->cli_encode_json($log)
        , program => $log->{program}
        , service => $log->{service}
        , pid => $log->{pid}
      }), ";\n";
    }

  } else {
    $self->SUPER::cli_output($list);
  }
}

sub sql_insert_with_queue_id {
  (my MY $self, my ($tabName, $queue_id), my QRec $record) = @_;
  $self->sql_insert($tabName, [queue_id => $queue_id], $record);
}

sub sql_insert {
  (my MY $self, my ($tabName, @item)) = @_;
  my (@keys, @values);
  foreach my $item (@item) {
    if (ref $item eq 'ARRAY') {
      my @kv = @$item;
      while (my ($key, $value) = splice @kv, 0, 2) {
        push @keys, $self->sql_safe_keyword($key);
        push @values, $self->sql_quote($value)
      }
    }
    elsif (ref $item eq 'HASH') {
      foreach my $key (sort keys %$item) {
        push @keys, $self->sql_safe_keyword($key);
        push @values, $self->sql_quote($item->{$key});
      }
    }
  }

  "INSERT into $tabName(".join(", ", @keys).")"
    . " VALUES(".join(", ", @values).")"
}

sub sql_update {
  (my MY $self, my ($tabName, $queue_id), my QRec $record) = @_;
  my @keys = $record ? sort keys %$record : ();
  "UPDATE $tabName SET ".join(", ", map {
    $self->sql_safe_keyword($_). " = " . $self->sql_quote($record->{$_})
  } @keys)
    ." WHERE queue_id = ".$self->sql_quote($queue_id);
}

sub sql_encode {
  (my MY $self, my ($encKey, $value)) = @_;
  "INSERT or IGNORE into $encKey(".join(", ", $encKey).")"
    . "VALUES(".join(", ", map {$self->sql_quote($_)} $value).")"
}

sub sql_safe_keyword {
  (my MY $self, my $str) = @_;
  $str =~ s/^(from|to)\z/"$1"/g;
  $str =~ s/-/_/gr;
}

sub sql_quote {
  (my MY $self, my $str) = @_;
  return 'NULL' unless defined $str;
  return $str if $str =~ /^\d+\z/;
  $str =~ s{\'}{''}g;
  qq!'$str'!;
}

sub parse_following {
  (my MY $self, my ($following, $information)) = @_;

  return +{} unless $following =~ /=/;

  my QRec $qrec = $self->extract_fromtolike_pairs([split /,\s*/, $following]);

  if ( exists $qrec->{client} && defined $qrec->{client} ) {
    ($qrec->{client_hostname}, $qrec->{client_ipaddr})
      = $self->extract_client_hostname_ipaddr($qrec->{client});
  }
  if ( $information && $qrec->{status} ) {
    $qrec->{information} = $information;
  }

  $qrec;
}

sub extract_client_hostname_ipaddr {
  (my MY $self, my $client) = @_;
  my ($hostname, $ipaddr, $port) = $client =~ /^(.+?)\[([0-9.]+)\](?::(\d+))?/;
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

  for my $key ( qw(from to orig_to) ) {
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
  return sprintf '%d-%02d-%02d %s', $self->{year}, $mon, $day, $hhmmss;
}

sub skew_date {
  (my MY $self, my $date) = @_;

  my $cur_mm_dd = join '-', (split m{-}, $date)[1,2];

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

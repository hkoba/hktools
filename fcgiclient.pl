#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;

use IO::Socket::UNIX;
use URI;
use FCGI::Client;

sub MY () {__PACKAGE__}
use fields qw/socket client/;

sub usage {
  die <<END;
Usage: $0 SOCKFILE 'GET|POST' PATH_INFO Q=V Q=V...
END
}

{
  my MY $self = fields::new(MY);
  usage() unless @ARGV;

  my $sockfile = shift;
  my $method = shift || 'GET';
  my $path = shift || '/';

  my $qs = do {
    my $uri = URI->new($path);
    $uri->query_form(map {
      my ($k, $v) = split /=/, $_, 2;
      ($k, $v // 1);
    } @ARGV);
    $uri->query;
  };

  $self->{socket} = IO::Socket::UNIX->new(Peer => $sockfile);
  $self->{client} = FCGI::Client::Connection->new(sock => $self->{socket});

  my ($out, $err, $stat)
    = $self->{client}->request(+{REQUEST_METHOD => $method
				 , PATH_INFO => $path
				 , (defined $qs ?
				    (QUERY_STRING => $qs) : ())
				}
			       , "");
  local $_;
  print "STAT: $stat\n" if defined $stat;
  print "ERR: $err\n" if defined $err;
  print "OUT: $out\n";
}

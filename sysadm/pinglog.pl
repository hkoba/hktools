#!/usr/bin/perl -w
use strict;
use warnings FATAL => qw(all);

use Net::Ping;
use Getopt::Long;
use List::Util qw(sum);
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);
use Data::Dumper;
use FileHandle;

sub usage;
sub log_fh;

my $timefmt = '%Y-%m-%dT%H:%M:%S';
my $summarize;
my $ping_interval = 5;
my $timeout = 1;
my $DEBUG = 0;

my $logfile;

#----------------------------------------
GetOptions("o|output=s", \$logfile,
	   "t|timefmt=s", \$timefmt,
	   "ping_interval=i", \$ping_interval,
	   "s|summarize=i", \$summarize,
	   "d|debug", \$DEBUG,
	  )
  or usage;

#----------------------------------------

if (defined $summarize) {
  __PACKAGE__->summarize($summarize, @ARGV);
} else {
  @ARGV or usage;

  if (defined $logfile) {
    $logfile = File::Spec->rel2abs($logfile)
      unless File::Spec->file_name_is_absolute($logfile);
    daemonize();
  }
  eval {
    __PACKAGE__->poll(@ARGV);
  };
}

if ($@) {
  my $fh;
  if (defined $logfile) {
    open $fh, '>>', $logfile or die "Can't open $logfile";
  } else {
    $fh = \*STDERR;
  }
  print $fh $@;
  exit 1;
}

#----------------------------------------

sub poll {
  my ($self, $host) = (shift, shift);
  my $ping = new Net::Ping(icmp => $timeout);
  $ping->hires;
  my $fh = log_fh($logfile);
  autoflush $fh 1;
  while (1) {
    my ($time, $usec) = gettimeofday;
    $usec /= 1000000;
    my $now = $time + $usec;
    my $sleep = $ping_interval - ($time % $ping_interval) - $usec;
    print STDERR "at $time, sleep $sleep\n" if $DEBUG;
    Time::HiRes::sleep($sleep);
    ($time) = gettimeofday;
    my ($ret, $msec, $ip) = $ping->ping($host);
    print $fh strftime($timefmt, localtime $time)
      , "\t", $ret ? sprintf("%.3f", $msec) : "-", "\n";
  }
}

# compute STDEVP
sub summarize {
  my ($self, $columns) = splice @_, 0, 2;
  local @ARGV = @_;
  local $_;
  my $emiter = sub {
    my ($time, $n_try, $n_ok, $sum, $sum2) = @_;
    my $avg = $n_ok ? $sum / $n_ok : 0;
    my $sigma = $n_ok ? sqrt(($n_ok * $sum2 - $sum**2)/$n_ok**2) : 0;
    my $nfail = $n_try - $n_ok;
    printf "%s\t%.3f\t%.3f\t%s\n", $time
      , $avg, $sigma, $nfail || "";
  };
  my $last_time;
  my ($n_try, $n_ok, $sum, $sum2) = (0) x 4;
  while (<>) {
    chomp;
    my ($time, $msec) = split " ", $_, 2;
    $time = substr($time, 0, $columns);
    if (defined $last_time
	and $last_time ne $time) {
      $emiter->($last_time,
		$n_try, $n_ok, $sum, $sum2);
      ($n_try, $n_ok, $sum, $sum2) = (0) x 4;
    }

    $n_try++;
    if ($msec ne '-') {
      $n_ok++;
      $msec *= 1000;
      $sum += $msec;
      $sum2 += $msec ** 2;
    }
    $last_time = $time;
  }
  $emiter->($last_time,
	    $n_try, $n_ok, $sum, $sum2);
}

sub usage {
  die <<END;
Usage: $0 host
END
}

sub log_fh {
  my ($fn) = @_;
  return \*STDOUT unless defined $fn;
  open my $fh, '>>', $fn or die "Can't open $fn: $!";
  open STDERR, '>&', $fh or die "Can't redirect STDERR to $fn: $!";
  $fh;
}

use POSIX 'setsid';
sub daemonize {
  chdir '/'               or die "Can't chdir to /: $!";
  open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
  open STDOUT, '>/dev/null'
    or die "Can't write to /dev/null: $!";
  defined(my $pid = fork) or die "Can't fork: $!";
  exit if $pid;
  setsid                  or die "Can't start a new session: $!";
  open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
}

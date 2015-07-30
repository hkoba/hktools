#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;
use Carp;

#========================================
use fields qw/o_table
	      o_create
	      o_transaction
	      columns

	      enc_cache
	     /;
sub MY () {__PACKAGE__}

package ColSpec {
  use fields qw/ltsv_name
		col_name
		id_name
		colno
		type
		encoded/;
};

#========================================

sub usage {
  die <<EOF;
Usage: $0 [-c] [--table=NAME] ACCESS_LOG...

-c --create    emit DDL(create table) too.
--table=TAB    specify table name
EOF
}


{
  my MY $opts = fields::new(MY);
  $opts->parse_argv(\@ARGV, c => 'create');
  $opts->{o_table} //= 'access';
  $opts->{o_transaction} //= 1;

  $opts->add_column(host => enc => 1);
  $opts->add_column(begin => type => 'datetime');
  $opts->add_column(method => enc => 1);
  $opts->add_column(path => enc => 1);
  $opts->add_column(status => type => 'integer');
  $opts->add_column(size => type => 'integer');
  $opts->add_column('referer');
  $opts->add_column(ua => enc => 1);

  print "BEGIN;\n" if $opts->{o_transaction};

  print $opts->as_create if $opts->{o_create};

  while (<>) {
    chomp;
    print $opts->array_as_insert(parse($_));
  }

  print "COMMIT;\n" if $opts->{o_transaction};
}

BEGIN {

  our %MONTH_NAMES = qw(
			 Jan 01
			 Feb 02
			 Mar 03
			 Apr 04
			 May 05
			 Jun 06
			 Jul 07
			 Aug 08
			 Sep 09
			 Oct 10
			 Nov 11
			 Dec 12);

  our $CLF_TIME = qr{
		     \[
		     (?:
		       (\d{2})
		       / (Jan|Feb|Mar|Apr|May|Jun
		       |Jul|Aug|Sep|Oct|Nov|Dec)
		       / (\d{4})
		       : (\d{2}) : (\d{2}) : (\d{2})
		       \s ([\+\-]\d{4})
		     )
		     \]
		 }x;

  # このパターンは、
  # こういう文字列にマッチし、
  # [21/Apr/1997:16:21:01 +0900]

  # [] の中身と、
  # その中の各要素を返す。

  sub seconds {
    my ($date, $month, $year, $hour, $min, $sec, $tz) = $_[0] =~ $CLF_TIME
      or croak "Can't extract CLF_TIME from $_[0]";

    sprintf("%04d-%02d-%02d %02d:%02d:%02d %s"
	    , $year, $MONTH_NAMES{$month}, $date
	    , $hour, $min, $sec
	    , $tz);
  }

  our $CLF =
    qr{
	^ (?:(\S+)\s)?         ### VHOST
	(\S+)\s(\S+)\s(\S+)    # IP, ident-user, auth-user
	\s(\[[^]]+\])          # time
	\s"((?:[^\\\"]|\\.)*)" # request
	\s(\S+)\s(\S+)         # status, nbytes
	# ------- (combined) -----
	(?:
	  \s"((?:[^\\\"]|\\.)*)" # referer
	  \s"((?:[^\\\"]|\\.)*)" # agent
	  (?:
	    # ------- (ssri-extension) -----
	    \s(\S+)         # exit status
	    \s(\S+)         # consumed time
	    (?: \s(\S+) )?  # tracking cookie(Apache)
	  )?
	)?
    }x;

  sub parse {
    my ($vhost, $ip, $ident__, $user
	, $clftime, $req
	, $status, $nbytes
	, $referer, $agent, $exit, $elapsed, $cookie)
      = do {
	unless (@_) {
	  $_ =~ $CLF;
	} else {
	  $_[0] =~ $CLF;
	}
      }
      or return;

    my $bad_req;
    my ($method, $loc, $ver) = $req
      =~ m{^(\w+)\s+(\S+)\s+(\w+/[\d\.]+)}x
	or $bad_req = $req
	  if defined $req and $status < 400;

    [$ip
     , seconds($clftime)
     , $method
     , $loc
     , $status
     , $nbytes
     , $referer
     , $agent
    ]
  }
}

sub add_column {
  (my MY $opts, my ($colName, %opts)) = @_;
  push @{$opts->{columns}}, my ColSpec $col = fields::new('ColSpec');
  $col->{colno} = @{$opts->{columns}} - 1;
  $col->{col_name} = $colName;
  $col->{ltsv_name} = $opts{ltsvname} || $col->{col_name};
  $col->{type} = $opts{type} // 'text';
  if ($col->{encoded} = $opts{enc}) {
    $col->{id_name} = "$col->{col_name}_id";
  }
  $col;
}

sub as_create {
  (my MY $opts) = @_;
  my (@ddl, @indices);
  foreach my ColSpec $col (@{$opts->{columns}}) {
    next unless $col->{encoded};
    push @ddl, $opts->sql_create
      ($col->{col_name}, "$col->{id_name} integer primary key"
       , "$col->{col_name} text unique").";";
    # XXX:
    push @indices
      , "CREATE INDEX if not exists $opts->{o_table}_$col->{id_name}"
	. " on $opts->{o_table}($col->{id_name});";
  }

  push @ddl, $opts->sql_create($opts->{o_table}, map {
    my ColSpec $col = $_;
    if ($col->{encoded}) {
      "$col->{id_name} integer";
    } else {
      "$col->{col_name} $col->{type}";
    }
  } @{$opts->{columns}})."\n;";

  # XXX: column name quoting
  push @ddl, "CREATE VIEW if not exists v_$opts->{o_table}"
    . " AS SELECT ".join(", ", map {
      my ColSpec $col = $_;
      if ($col->{encoded}) {
	"$col->{col_name}.$col->{col_name} as $col->{col_name}"
      } else {
	$col->{col_name};
      }
  } @{$opts->{columns}})." FROM "
    .join(" LEFT JOIN ", $opts->{o_table}, map {
      my ColSpec $col = $_;
      if ($col->{encoded}) {
	"$col->{col_name} using ($col->{id_name})"
      } else {
	();
      }
    } @{$opts->{columns}}).";";

  join("\n", @ddl, @indices)."\n";
}

sub array_as_insert {
  (my MY $opts, my $log) = @_;
  my ($primary, @encoder) = $opts->sql_values($log, @{$opts->{columns}});
  (@encoder
   , "INSERT INTO ".$opts->sql_insert($opts->{o_table}, $opts->column_names)
   . " $primary;\n");
}

#========================================

sub sql_create {
  (my MY $opts, my ($table, @coldefs)) = @_;
  "CREATE TABLE if not exists $table(". join(", ", @coldefs). ")";
}

sub sql_insert {
  (my MY $opts, my ($table, @columns)) = @_;
  "$table(".join(",", @columns).")";
}

sub sql_values {
  (my MY $opts, my ($log, @coldefs)) = @_;

  unless (@$log == @coldefs) {
    croak "column length mismatch! log=".@$log. " vs defs=".@coldefs;
  }

  my @encoder;
  my $primary = "VALUES (".join(",", map {
    my ColSpec $col = $_;
    if (not defined (my $value = $log->[$col->{colno}])) {
      'NULL'
    } elsif ($col->{encoded}) {
      unless ($opts->{enc_cache}{$col->{col_name}}{$value}++) {
	push @encoder, $opts->sql_encode($col->{col_name}, $value);
      }
      # ensure encoded
      $opts->sql_select_encoded($col->{col_name}, $value)
    } else {
      $opts->sql_quote($value)
    }
  } @coldefs).")";

  ($primary, @encoder);
}

sub sql_encode {
  (my MY $opts, my ($colname, $value)) = @_;
  "INSERT or IGNORE into ".$opts->sql_insert($colname, $colname)
    . " VALUES(".$opts->sql_quote($value).");\n";
}

sub sql_select_encoded {
  (my MY $opts, my ($colname, $value)) = @_;
  "(SELECT ${colname}_id from $colname where $colname = "
    .$opts->sql_quote($value).")";
}

sub sql_quote {
  (my MY $opts, my $str) = @_;
  $str =~ s{\'}{''}g;
  qq!'$str'!;
}

sub column_names {
  (my MY $opts) = @_;
  map {
    my ColSpec $col = $_;
    $col->{id_name} // $col->{col_name}
  } @{$opts->{columns}}
}

sub accept_column_option {
  (my MY $opts, my $match) = @_;
  push @{$opts->{columns}}, my ColSpec $col = fields::new('ColSpec');
  $col->{col_name} = $match->{key};
  $col->{ltsv_name} = $match->{ltsvname} || $col->{col_name};
  $col->{type} = $match->{type} // 'text';
  if ($col->{encoded} = $match->{enc}) {
    $col->{id_name} = "$col->{col_name}_id";
  }
  $col;
}

sub parse_argv {
  (my MY $opts, my ($argv, %opt_alias)) = @_;
  while (@$argv and $argv->[0]
	 =~ m{^--?(?<opt>\w+)(?:=(?<val>.*))?}x) {
    if (defined $+{opt}) {
      my $o = $opt_alias{$+{opt}} || $+{opt};
      $opts->{"o_$o"} = $+{val} // 1;
    } else {
      die "really?";
    }
    shift @$argv;
  }
  $opts;
}

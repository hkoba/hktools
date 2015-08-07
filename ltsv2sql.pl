#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;

#========================================
use fields qw/o_table
	      o_create
	      o_transaction
	      o_help
	      columns

	      enc_cache
	     /;
sub MY () {__PACKAGE__}

package ColSpec {
  use fields qw/ltsv_name
		col_name
		id_name
		type
		encoded/;
};

use Scalar::Util qw/looks_like_number/;

#========================================

sub usage {
  die <<EOF;
Usage: $0 +COL +COL...  LTSV_FILE...

-c --create    emit DDL(create table) too.
--table=TAB    specify table name

+COL           Column to be taken from LTSV
+COL=LOG       Like above, but with renaming
+COL=LOG=TYPE  Like above, but with explicit column type
++COL          Like above, but with separate (encoding) table.
EOF
}

#========================================

{
  my MY $opts = fields::new(MY);
  $opts->parse_argv(\@ARGV, c => 'create', h => 'help');

  usage() if $opts->{o_help};

  $opts->{o_table} //= 'access';
  $opts->{o_transaction} //= 1;

  unless ($opts->{columns} and @{$opts->{columns}}) {
    usage();
  }

  print "BEGIN;\n" if $opts->{o_transaction};

  print $opts->as_create if $opts->{o_create};

  while (<>) {
    chomp;
    my %log = map {split ":", $_, 2} split "\t";
    print $opts->as_insert(\%log);
  }

  print "COMMIT;\n" if $opts->{o_transaction};
}

#========================================

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
  push @ddl, "CREATE VIEW if not exists raw_$opts->{o_table}"
    . " AS SELECT $opts->{o_table}.rowid as 'rowid', * FROM "
    .join(" LEFT JOIN ", $opts->{o_table}, map {
      my ColSpec $col = $_;
      if ($col->{encoded}) {
	"$col->{col_name} using ($col->{id_name})"
      } else {
	();
      }
    } @{$opts->{columns}}).";";

  push @ddl, "CREATE VIEW if not exists v_$opts->{o_table}"
    . " AS SELECT rowid, ".join(", ", map {
      my ColSpec $col = $_;
      $col->{col_name};
  } @{$opts->{columns}})." FROM raw_$opts->{o_table};";

  join("\n", @ddl, @indices)."\n";
}

sub as_insert {
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

  my @encoder;
  my $primary = "VALUES (".join(",", map {
    my ColSpec $col = $_;
    if (not defined (my $value = $log->{$col->{ltsv_name}})) {
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
  if (looks_like_number($str)) {
    $str
  } else {
    $str =~ s{\'}{''}g;
    qq!'$str'!;
  }
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

#========================================

sub parse_argv {
  (my MY $opts, my ($argv, %opt_alias)) = @_;
  while (@$argv and $argv->[0]
	 =~ m{^--?(?<opt>\w+)(?:=(?<val>.*))?
	    |^\+(?<enc>\+)?
	      (?<key>[^=\s]+)
	      (?:=(?<ltsvname>[^=]*)
		(?:=(?<type>[^=]+))?
	      )?
	   }x) {
    if (defined $+{key}) {
      $opts->accept_column_option(\%+);
    } elsif (defined $+{opt}) {
      my $o = $opt_alias{$+{opt}} || $+{opt};
      $opts->{"o_$o"} = $+{val} // 1;
    } else {
      die "really?";
    }
    shift @$argv;
  }
  $opts;
}

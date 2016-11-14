#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;
use 5.010;

#========================================
use fields qw/o_table
	      o_create
	      o_transaction
	      o_help
	      columns
	      encoder_dict

	      enc_cache
	     /;
sub MY () {__PACKAGE__}

{
  package ColSpec;
  use fields qw/ltsv_name
		col_name
		id_name
		type
		is_text
		encoded/;
  package EncTabSpec;
  use fields qw/tab_name
		id_col
		enc_col
		enc_type
	       /;
}

use Scalar::Util qw/looks_like_number/;

#========================================

sub usage {
  die <<EOF;
Usage: $0 [-c] [--table=TAB] +COL +COL...  LTSV_FILE...

-c --create    emit DDL(create table) too.
--table=TAB    specify table name

+COL           Column to be taken from LTSV
+COL=LOG       Like above, but with renaming (insert LOG as COL)

  You can specify column type as ':TYPE'

+COL:TYPE      Like above, but with explicit column type
+COL=LOG:TYPE  Like above, but with explicit column type

  You can also encode values into another table with leading '++'.

++COL          Like above, but with separate (encoding) table.
++COL=LOG
++COL=LOG:TYPE
++COL=LOG:ENC_TABLE.TYPE
++COL=LOG:ENC_TABLE.ENC_COL.TYPE
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

  if (@ARGV) {
    # To support DDL only mode.
    while (<>) {
      chomp;
      my %log = map {split ":", $_, 2} split "\t";
      print $opts->as_insert(\%log);
    }
  }

  print "COMMIT;\n" if $opts->{o_transaction};
}

#========================================

sub as_create {
  (my MY $opts) = @_;
  my (@ddl, @indices, %emitted);
  foreach my ColSpec $col (@{$opts->{columns}}) {
    my EncTabSpec $enc = $col->{encoded}
      or next;
    if (not $emitted{$enc->{tab_name}}++) {
      push @ddl, $opts->sql_create
	($enc->{tab_name}, "$enc->{id_col} integer primary key"
	 , "$enc->{enc_col} $enc->{enc_type} unique").";";
    }
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
  {
    my @explicit_cols;
    my @joins = map {
	my ColSpec $col = $_;
	if (my EncTabSpec $enc = $col->{encoded}) {
	  do {
	    if ($enc->{tab_name} eq $col->{col_name}) {
	      $col->{col_name};
	    } else {
	      "$enc->{tab_name} $col->{col_name}";
	    }
	  }.do {
	    if ($enc->{id_col} eq $col->{id_name}) {
	      " using ($col->{id_name})";
	    } else {
	      push @explicit_cols, "$col->{col_name}.$enc->{enc_col} as $col->{col_name}";
	      " ON $opts->{o_table}.$col->{id_name}"
		. " = $col->{col_name}.$enc->{id_col}";
	    }
	  };
	} else {
	  ();
	}
      } @{$opts->{columns}};
    push @ddl, "CREATE VIEW if not exists raw_$opts->{o_table}"
      . " AS SELECT $opts->{o_table}.rowid as 'rowid',"
      . join("", map(" $_,", @explicit_cols))
      . " * FROM "
      .join(" LEFT JOIN ", $opts->{o_table}, @joins).";";
  }

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
	push @encoder, $opts->sql_encode($col, $value);
      }
      # ensure encoded
      $opts->sql_select_encoded($col, $value)
    } else {
      $opts->sql_quote_col($col, $value)
    }
  } @coldefs).")";

  ($primary, @encoder);
}

sub sql_encode {
  (my MY $opts, my ColSpec $col, my ($value)) = @_;
  "INSERT or IGNORE into ".$opts->sql_insert($col->{col_name}, $col->{col_name})
    . " VALUES(".$opts->sql_quote_col($col, $value).");\n";
}

sub sql_select_encoded {
  (my MY $opts, my ColSpec $col, my ($value)) = @_;
  "(SELECT $col->{col_name}_id from $col->{col_name} where $col->{col_name} = "
    .$opts->sql_quote_col($col, $value).")";
}

sub sql_quote_col {
  (my MY $opts, my ColSpec $col, my $str) = @_;
  if (not $col->{is_text}
      and looks_like_number($str)) {
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
  $col->{is_text} = $col->{type} eq 'text';
  if ($col->{encoded} = $match->{enc}) {
    $col->{id_name} = "$col->{col_name}_id";

    my $enc_table = $match->{enc_table} || $col->{col_name};
    my EncTabSpec $tab = $opts->{encoder_dict}{$enc_table} // +{};
    # XXX: double creation
    $col->{encoded} = $tab;
    $tab->{tab_name} = $enc_table;
    $tab->{id_col} = "${enc_table}_id";
    $tab->{enc_col} = $match->{enc_col} || $enc_table;
    $tab->{enc_type} = $match->{enc_type} || 'text';
  }
  $col;
}

#========================================

sub parse_argv {
  (my MY $opts, my ($argv, %opt_alias)) = @_;
  while (@$argv and $argv->[0]
	 =~ m{^--?(?<opt>\w+)(?:=(?<val>.*))?
	    |^\+(?<enc>\+)?
	      (?<key>[^=:\s]+)
	      (?:=(?<ltsvname>[^=:]*)
		(?:=(?<type>[^=:]+))?
	      )?
	      (?::
		(?:(?<enc_table>\w+)
		  \.
		  (?:
		    (?<enc_col>\w+)
		    \.
		  )?
		)?
		(?<type>[^:]+))?
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

__END__

# For example:

spec=(
   +'begin:datetime'
   ++cookie=cookie.Apache
   ++host
   +query
   '+status:integer'
   '+size:integer'
   +referer
   ++ua
   ++method
   ++protocol
   '+port:integer'
   '+took_usec=usec:integer'
   +completed
)

ltsv2sql.pl -c $spec access_log.ltsv

# LogFormat "host:%h\tident:%l\tuser:%u\tstatus:%>s\tsize:%b\treferer:%{Referer}i\tua:%{User-Agent}i\tmethod:%m\tpath:%U%q\tprotocol:%H\tport:%{remote}p\tbegin:%{begin:%Y-%m-%d %H:%M:%S}t.%{begin:msec_frac}t %{%z}t\tusec:%D\tcompleted:%X\tcookie.Apache:%{Apache}C\tquery:%q" combined_ltsv

# CustomLog "logs/access_log.ltsv" combined_ltsv

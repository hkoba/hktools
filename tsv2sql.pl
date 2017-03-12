#!/usr/bin/env perl
use strict;
use warnings FATAL => qw/all/;
use Carp;

use File::Basename;

#========================================
use fields qw/o_table
              o_create
              o_transaction
              o_help
              columns
              colno_list
              db_col_list
              encoder_dict

              enc_cache
             /;
sub MY () {__PACKAGE__}

{
  package ColSpec;
  use fields qw/tsv_name
                tsv_colno
                db_col
                id_name
                type
                is_text
                unique
                encoded/;
  package EncTabSpec;
  use fields qw/tab_name
                id_col
                enc_col
                enc_type
                is_text
               /;
}

use Scalar::Util qw/looks_like_number/;

#========================================

sub usage {
  die <<EOF;
Usage: $0 [-c] [--table=TAB] +COL +COL...  TSV_FILE...

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

  $opts->{o_table} //= do {
    if (@ARGV) {
      rootname(basename($ARGV[0]));
    } else {
      't';
    }
  };
  $opts->{o_transaction} //= 1;

  print "BEGIN;\n" if $opts->{o_transaction};

  chomp(my $header = <>);
  $header =~ s/\r//;
  $header =~ s/^\xef\xbb\xbf//; # Trim BOM

  $opts->read_header(split "\t", $header);

  print $opts->as_create if $opts->{o_create};

  while (<>) {
    chomp;
    s/\r//;
    print $opts->as_insert([split "\t", $_, -1]), "\n";
  }

  print "COMMIT;\n" if $opts->{o_transaction};
}

#========================================

# 引数で指定されたのに header に無かったらエラーにすべきよね
sub read_header {
  (my MY $opts) = shift;
  my $tsv_coldict = coldict(my @tsv_collist = @_);
  $opts->{db_col_list} = \ my @dbcols;
  if ($opts->{columns}) {
    $opts->{colno_list} = \ my @watchCols;
    foreach my ColSpec $colspec (@{$opts->{columns}}) {
      defined (my $colno = $tsv_coldict->{$colspec->{tsv_name}})
	or croak "Can't find requested column $colspec->{tsv_name}";
      $colspec->{tsv_colno} = $colno;
      push @watchCols, $colno;
      push @dbcols, $colspec->{db_col};
    }
  } else {
    ...; # not yet supported.
    @dbcols = @tsv_collist;
  }
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
      "$col->{db_col} @{$col->{type}}";
    }
  } @{$opts->{columns}})."\n;";

  # XXX: column name quoting
  {
    my @explicit_cols;
    my @joins = map {
        my ColSpec $col = $_;
        if (my EncTabSpec $enc = $col->{encoded}) {
          do {
            if ($enc->{tab_name} eq $col->{db_col}) {
              $col->{db_col};
            } else {
              "$enc->{tab_name} $col->{db_col}";
            }
          }.do {
            if ($enc->{id_col} eq $col->{id_name}) {
              " using ($col->{id_name})";
            } else {
              push @explicit_cols, "$col->{db_col}.$enc->{enc_col} as $col->{db_col}";
              " ON $opts->{o_table}.$col->{id_name}"
                . " = $col->{db_col}.$enc->{id_col}";
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
      $col->{db_col};
  } @{$opts->{columns}})." FROM raw_$opts->{o_table};";

  join("\n", @ddl, @indices)."\n";
}

#========================================

sub as_insert {
  (my MY $opts, my $log) = @_;
  my ($primary, @encoder) = $opts->sql_values($log, @{$opts->{columns}});
  (@encoder
   , "INSERT INTO ".$opts->sql_insert($opts->{o_table}
                                      , @{$opts->{db_col_list}})
   . " $primary;\n");
}

sub coldict {
  my $i = 0;
  my %coldict;
  foreach my $qname (@_) {
    $coldict{$qname} = $i++;
  }
  \%coldict;
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
    if (not defined (my $value = $log->[$col->{tsv_colno}])) {
      'NULL'
    } elsif (my EncTabSpec $enc = $col->{encoded}) {
      unless ($opts->{enc_cache}{$enc->{tab_name}}{$value}++) {
        push @encoder, $opts->sql_encode($enc, $value);
      }
      # ensure encoded
      $opts->sql_select_encoded($enc, $value)
    } elsif ($col->{is_text} and $col->{unique} and $value eq '') {
      'NULL';
    } else {
      $opts->sql_quote($value, $col->{is_text})
    }
  } @coldefs).")";

  ($primary, @encoder);
}

sub sql_encode {
  (my MY $opts, my EncTabSpec $enc, my ($value)) = @_;
  "INSERT or IGNORE into ".$opts->sql_insert($enc->{tab_name}, $enc->{enc_col})
    . " VALUES(".$opts->sql_quote_col($enc, $value).");\n";
}

sub sql_select_encoded {
  (my MY $opts, my EncTabSpec $enc, my ($value)) = @_;
  "(SELECT $enc->{id_col} from $enc->{tab_name} where $enc->{enc_col} = "
    .$opts->sql_quote_col($enc, $value).")";
}

sub sql_quote {
  (my MY $opts, my ($str, $is_text)) = @_;
  if (not $is_text and looks_like_number($str)) {
    $str
  } else {
    $str =~ s{\'}{''}g;
    qq!'$str'!;
  }
}

sub sql_quote_col {
  (my MY $opts, my ColSpec $col, my $value) = @_;
  $opts->sql_quote($value, $col->{is_text});
}

sub column_names {
  (my MY $opts) = @_;
  map {
    my ColSpec $col = $_;
    $col->{id_name} // $col->{db_col}
  } @{$opts->{columns}}
}

sub accept_column_option {
  (my MY $opts, my $match) = @_;
  push @{$opts->{columns}}, my ColSpec $col = fields::new('ColSpec');
  $col->{db_col} = $match->{key};
  $col->{tsv_name} = $match->{tsvname} || $col->{db_col};
  $col->{type} = [split ":", $match->{type} // ""];
  $col->{type}[0] //= 'text';
  $col->{is_text} = $col->{type}[0] eq 'text';
  $col->{unique} = 1 if grep {$_ eq 'unique'} @{$col->{type}};
  if ($match->{enc} || $match->{enc_table}) {
    $col->{id_name} = "$col->{db_col}_id";

    my $enc_table = $match->{enc_table} || $col->{db_col};
    my EncTabSpec $tab = $opts->{encoder_dict}{$enc_table} // +{};
    # XXX: double creation
    $col->{encoded} = $tab;
    $tab->{tab_name} = $enc_table;
    $tab->{id_col} = "${enc_table}_id";
    $tab->{enc_col} = $match->{enc_col} || $enc_table;
    $tab->{enc_type} = $col->{type}[0];
    $tab->{is_text} = $col->{is_text};
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
              (?:=(?<tsvname>[^=:]*)
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
                (?<type>[^.:].*))?
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

sub rootname {
  my ($fn) = @_;
  $fn =~ s/\.[^\.]+$//;
  $fn;
}

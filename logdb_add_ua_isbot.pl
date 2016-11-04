#!/usr/bin/env perl
# -*- coding: utf-8 -*-
use strict;
use warnings;

use HTTP::BrowserDetect;
use DBIx::TransactionManager;
use DBIx::Sunny;

{
  my $dbname = shift;

  # I don't want to use WAL mode here for SQLite.
  my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname"
			 , undef, undef
			 , {RootClass => 'DBIx::Sunny'
			    , PrintError => 0
			    , RaiseError => 1
			    , AutoCommit => 1});

  if (not has_column($dbh, qw(ua is_bot))) {
    $dbh->do(q(alter table ua add column is_bot integer not null default 0));
  }

  my $tm = DBIx::TransactionManager->new($dbh);
  {
    my $txn = $tm->txn_scope;

    my $set_is_bot = do {
      my $sth = $dbh->prepare("update ua set is_bot = ? where ua_id = ?");
      sub { $sth->execute(@_) };
    };

    foreach my $row (lexpand($dbh->select_all(q(select * from ua)))) {

      my $is_bot = do {
	if ($row->{ua} =~ /Google Favicon$/ or $row->{ua} !~ m{\w+/}) {
	  1;
	} else {
	  my $detector = HTTP::BrowserDetect->new($row->{ua});
	  $detector->robot;
	}
      };

      $set_is_bot->($is_bot ? 1 : 0, $row->{ua_id});
    }

    $txn->commit;
  }
}

sub lexpand {
  (defined $_[0] && ref $_[0]) ? @{$_[0]} : ()
}

sub has_column {
  my ($dbh, $table, $column) = @_;
  my @info = $dbh->column_info(undef, undef, $table, $column)->fetchrow_array
    or return;
  wantarray ? @info : 1;
}

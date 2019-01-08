#!/usr/bin/env perl
package SlashBar::NginxConfig;
use strict;
use File::AddInc;
use SlashBar -as_base
  , [fields =>
       , [root => default => "/webapp"
          , doc => "Physical root directory of mapped webapps"]
       , [try_ext => doc => "File extension for try_file_list"]
       , [save_try_as_var => default => '$alias_path']
       , [include_for_dynamic => default => ''
          , doc => 'nginx conf for dynamic locations']
     ]
  ;

sub generate_for_sample_url {
  (my MY $self, my $sample_url) = @_;

  unless ($sample_url) {
    $self->cmd_help("Not enough argument! generate_for_sample_url /SAMPLE/URL/-/LIKE/THIS\n");
  }

  my ($reList, $varList) = $self->regexp_for_sample_url($sample_url);

  my @res;

  push @res, $self->gen_try_file_list($reList, $varList);

  @res;
}

sub test_match {
  (my MY $self, my ($sample_url, @other_url)) = @_;
  my ($reList, $varList) = $self->regexp_for_sample_url($sample_url);
  my $locationStr = join("", @$reList);
  ("^$locationStr\$",
  map {
    if (my @match = /^$locationStr$/) {
      [OK => "URL:$_", \@match, +{%+}]; # 
    } else {
      [FAIL => "URL:$_"];
    }
  } ($sample_url, @other_url));
}

sub extensions {
  (my MY $self) = @_;
  # XXX: .yatt vs yatt
  # XXX: comman separated list
  MOP4Import::Util::lexpand($self->{try_ext});
}

sub gen_try_file_list {
  (my MY $self, my ($reList, $varList)) = @_;

  my $locationRe = '^'.join("", @$reList).'$';

  my @res;
  push @res, "location ~ $locationRe \{";
  push @res, sprintf(q{  set $public_root %s$appPrefix/public;}, $self->{root});
  foreach my $var (@$varList) {
    if ($var =~ /^w/) {
      foreach my $ext ($self->extensions) {
        push @res, sprintf(q|  if (-f $public_root$%s%s) {|, $var, $ext);
        push @res, sprintf(q|    set %s $public_root$%s%s$rest;|, $self->{save_try_as_var}, $var, $ext);
        push @res, "    break;";
        push @res, "  }";
      }
    } elsif ($var =~ /^s/) {
      # s0, s1... ends with /
      foreach my $ext ($self->extensions) {
        push @res, sprintf(q|  if (-f $public_root${%s}index%s) {|, $var, $ext);
        push @res, sprintf(q|    set %s $public_root${%s}index%s$rest;|, $self->{save_try_as_var}, $var, $ext);
        push @res, "    break;";
        push @res, "  }";
      }
    }
  }
  push @res, q|  if (!-f $request_uri) {|;
  push @res, q|    return 404;|;
  push @res, q|  }|;
  push @res, q|  alias $public_root;|;
  if ($self->{include_for_dynamic}) {
    push @res, sprintf(q|  include "%s";|, $self->{include_for_dynamic});
  }
  push @res, "}";

  join("\n", @res)."\n";
}

MY->run(\@ARGV) unless caller;

1;

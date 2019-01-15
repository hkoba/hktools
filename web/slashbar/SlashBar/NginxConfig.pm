#!/usr/bin/env perl
package SlashBar::NginxConfig;
use strict;
use File::AddInc;
use SlashBar -as_base
  , [fields =>
       , [root => default => "/web/subapps"
          , doc => "Physical root directory of mapped webapps"]
       , [try_ext => doc => "File extension for try_file_list"]
       , [save_try_as_var => default => '$alias_path']
       , [include_for_dynamic => default => ''
          , doc => 'nginx conf for dynamic locations']
       , [upstream_pass_statement => default => ''
          , doc => 'nginx statement for upstream pass (proxy_pass, fastcgi_pass)']
       , [no_comment => doc => "Omit comment for generated location blocks"]
     ]
  ;

sub cmd_generate_for_sample_url {
  (my MY $self, my $sample_url) = @_;

  print $self->generate_for_sample_url($sample_url), "\n";
}

sub generate_for_sample_url {
  (my MY $self, my $sample_url) = @_;

  unless ($sample_url) {
    $self->cmd_help("Not enough argument! generate_for_sample_url /SAMPLE/URL/-/LIKE/THIS\n");
  }

  my ($reList, $varList) = $self->regexp_for_sample_url($sample_url);

  my @res;

  push @res, $self->gen_static($reList, $varList);

  push @res, $self->gen_outer_location(
    $reList, $varList,
    [$self->gen_explicit_ext($reList, $varList)],
    [$self->gen_rewrite_file_list($reList, $varList)],
  );

  @res;
}

sub test_match {
  (my MY $self, my ($sample_url, @other_url)) = @_;
  my ($reList, $varList) = $self->regexp_for_sample_url($sample_url);
  my $locationStr = join("", @$reList);
  ("^$locationStr\$",
  map {
    if (my @match = /^$locationStr$/) {
      [OK => "URL:$_", \@match, +{%+}];
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

sub gen_static {
  (my MY $self, my ($reList, $varList)) = @_;

  my ($prefix, $sep, @rest) = @$reList;

  my $locationRe = "^$prefix$sep/static(?<rest>/.*)\$";

  my @res;
  push @res, "# static block" unless $self->{no_comment};
  push @res, "location ~ $locationRe \{";
  push @res, sprintf(q{  alias %s$appPrefix.webapp/static$rest;}, $self->{root});
  push @res, "}", "";

  join("\n", @res)."\n";
}

sub gen_outer_location {
  (my MY $self, my ($reList, $varList, @innerBlock)) = @_;

  my ($prefix, $sep, @rest) = @$reList;

  my $locationRe = "^$prefix$sep(?<orig_rest>/.*)\$";

  my @res;
  push @res, "# dynamic block" unless $self->{no_comment};
  push @res, "location ~ $locationRe \{";
  push @res, sprintf(q{  set $app_root %s$appPrefix.webapp;}, $self->{root});
  push @res, sprintf(q{  set $public_root $app_root/public;});
  push @res, sprintf(q|  alias $public_root$orig_rest;|);

  push @res, map {("", map("  $_", @$_))} @innerBlock;

  push @res, "}";

  map {s/\n*$/\n/r} @res;
}

sub gen_explicit_ext {
  (my MY $self, my ($reList, $varList)) = @_;

  my ($prefix, $sep, @rest) = @$reList;

  my $extRe = join("|", map {quotemeta($_)} $self->extensions);

  my $locationRe = "^$prefix$sep(?<file>/.*?(?:$extRe))(?<rest>/.*)?\$";

  my @res;
  push @res, "# explicit_ext block" unless $self->{no_comment};
  push @res, "location ~ $locationRe \{";
  push @res, sprintf(q{  set $app_root %s$appPrefix.webapp;}, $self->{root});
  push @res, sprintf(q{  set $public_root $app_root/public;});
  if ($self->{include_for_dynamic}) {
    push @res, sprintf(q|  include "%s";|, $self->{include_for_dynamic});
  }
  push @res, q|  fastcgi_split_path_info ^((?:/[^-\./]+)*/-)(/.*)$;|;
  push @res, sprintf(q|  set %s $public_root$file$rest;|, $self->{save_try_as_var});
  push @res, sprintf(q|  if (-f $public_root$file) {|);
  push @res, "    $self->{upstream_pass_statement};" if $self->{upstream_pass_statement};
  push @res, "    break;";
  push @res, "  }";
  push @res, "}";

  map {"$_\n"} @res;
}

sub gen_rewrite_file_list {
  (my MY $self, my ($reList, $varList)) = @_;

  my ($prefix, $sep, @rest) = @$reList;

  my $locationRe = '^'.join("", @$reList).'$';

  my @res;
  push @res, "# rewrite_file_list block" unless $self->{no_comment};
  push @res, "location ~ $locationRe \{";
  push @res, sprintf(q{  set $app_root %s$appPrefix.webapp;}, $self->{root});
  push @res, sprintf(q{  set $public_root $app_root/public;});

  #   foreach my $var (@$varList)
  for (my $vn = $#$varList; $vn >= 0; $vn--) {
    my $var = $varList->[$vn];
    if ($var =~ /^w/) {
      my $path = join "", map('$'.$_, @{$varList}[0..$vn-1]), sprintf(q|${%s}|, $var);

      my $suffix = join "", map {'$'.$_} @{$varList}[($vn+1) .. $#$varList];

      foreach my $ext ($self->extensions) {
        push @res, sprintf(q|  if (-f $public_root%s%s) {|, $path, $ext);
        push @res, sprintf(q|    rewrite ^.*$ $appPrefix/-%s%s%s$rest last;|, $path, $ext, $suffix);
        push @res, "  }";
      }
    } elsif ($var =~ /^s/) {
      # s0, s1... ends with /

      my $path0 = join "", map('$'.$_, @{$varList}[0..$vn-1]);
      my $suffix = join "", map {'$'.$_} @{$varList}[($vn) .. $#$varList];

      push @res, sprintf(q|  set $file $public_root%s$rest;|, $path0);
      push @res, '  if (-f $file) {';
      push @res, "    break;";
      push @res, "  }";

      my $path1 = join "", map('$'.$_, @{$varList}[0..$vn-1]), sprintf(q|${%s}|, $var);
      foreach my $ext ($self->extensions) {
        push @res, sprintf(q|  if (-f $public_root%sindex%s) {|, $path1, $ext);
        push @res, sprintf(q|    rewrite ^.*$ $appPrefix/-%sindex%s%s$rest last;|, $path1, $ext, $suffix);
        push @res, "  }";
      }
    } else {
      die "really??";
    }
  }
  push @res, q|  if (!-f $request_uri) {|;
  push @res, q|    return 404;|;
  push @res, q|  }|;
  push @res, "}";

  map {"$_\n"} @res;
}

MY->run(\@ARGV) unless caller;

1;

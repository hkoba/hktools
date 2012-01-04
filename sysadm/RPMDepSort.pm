#!/usr/bin/perl -w
package RPMDepSort;
use strict;
use warnings FATAL => qw(all);
sub MY () {__PACKAGE__}

use RPM2;
use Data::Dumper;

{
  sub PkgDep () {'RPMDepSort::PkgDep'}
  package RPMDepSort::PkgDep;
  sub PkgDep () {__PACKAGE__}
  use fields qw(pkg pkgName provide require whatrequires);
  sub new {
    my $class = shift;
    my PkgDep $self = fields::new($class);
    $self->{pkg} = shift;
    $self->{pkgName} = $_[0]; # will not shift;
    $self->{provide}{$_} = 1 for @_;
    $self;
  }
  sub add_requires {
    my PkgDep $self = shift;
    $self->{require}{$_} = 1 for @_;
    $self;
  }
  sub fixup {
    my PkgDep $self = shift;
    # Remove self dependency.
    foreach my $k (keys %{$self->{provide}}) {
      delete $self->{require}{$k};
      delete $self->{whatrequires}{$k};
    }
    # Remove rpmlib(*) dependency too.
    foreach my $k (grep {/^rpmlib\(/} keys %{$self->{require}}) {
      delete $self->{require}{$k};
    }
    $self;
  }
}

sub sort_by_whatrequires {
  my ($self, $deps) = @_;
  sort {
    keys %{$a->{whatrequires}} <=> keys %{$b->{whatrequires}}
      ||    $a->{pkgName} cmp $b->{pkgName}
  } values %$deps;
}

sub sort_by_requires {
  my ($self, $deps) = @_;
  sort {
    keys(%{$a->{require}}) <=> keys(%{$b->{require}})
      ||    $a->{pkgName} cmp $b->{pkgName}
  } values %$deps;
}

sub sort_by_provides {
  my ($self, $deps) = @_;
  sort {
    keys(%{$a->{provide}}) <=> keys(%{$b->{provide}})
      ||    $a->{pkgName} cmp $b->{pkgName}
  } values %$deps;
}

sub list_nondeps {
  my ($deps) = @_;
  my @res;
  foreach my PkgDep $dep (values %$deps) {
    next if %{$dep->{require}};
    push @res, $dep;
  }
  @res;
}

sub build_dependency {
  my ($db, $filter_match, $fixup) = @_;

  my %deps;
  my $all = $db->find_all_iter;
  local $_;
  while (my $pkg = $all->next) {
    $_ = my $pkgName = $pkg->name;
    if ($filter_match) {
      $filter_match->($pkg)
	or next;
    }
    $deps{$pkgName} = my PkgDep $dep
      = PkgDep->new($pkg, $pkgName, $pkg->provides);
    $dep->add_requires($pkg->requires);
  }

  foreach my PkgDep $dep (values %deps) {
    foreach my $prov (keys %{$dep->{provide}}) {
      $dep->{whatrequires}{$_} = 1 for map {
	$_->name
      } $db->find_by_requires($prov);
    }
  }

  foreach my PkgDep $dep (values %deps) {
    $dep->fixup;
    $fixup->($dep) if $fixup;
  }

  \%deps;
}

#========================================-

sub emit_deps {
  my ($pack, $deps) = @_;
  print join("\t", '#nreq', 'name', 'whatrequires...'), "\n";
  foreach my PkgDep $dep ($pack->sort_by_whatrequires($deps)) {
    my @whreqs = sort keys %{$dep->{whatrequires}};
    print join("\t", scalar @whreqs, $dep->{pkg}->name, @whreqs), "\n";
  }
}

sub cmd_whatrequires {
  my ($pack) = @_;
  my $deps = build_dependency(my $db = RPM2->open_rpm_db
			      , sub {
				! /-debuginfo$/
			      });
  $pack->emit_deps($deps);
}

sub cmd_perl {
  my ($pack) = @_;
  my $deps = build_dependency(my $db = RPM2->open_rpm_db
			      , sub {
				/^perl-/ && !/-debuginfo$/
			      }
			      , \&perl_fixup
			     );
  $pack->emit_deps($deps);
}

sub perl_fixup {
  (my PkgDep $dep) = @_;
  foreach my $k (grep {/^perl\((?::MODULE_COMPAT[\w\.]+)\)/}
		 keys %{$dep->{require}}) {
    delete $dep->{require}{$k};
  }
}

#========================================
unless (caller) {
  my $cmd = shift || 'whatrequires';
  my $sub = MY->can("cmd_$cmd")
    or die "No such command: $cmd\n";

  $sub->(MY, @ARGV);
}

1;

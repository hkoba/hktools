#!/usr/bin/perl -w
use strict;
use warnings FATAL => qw(all);
use RPM2;
use Data::Dumper;

{
  package PkgDep;
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
    }
    # Remove rpmlib(*) dependency too.
    foreach my $k (grep {/^rpmlib\(/} keys %{$self->{require}}) {
      delete $self->{require}{$k};
    }
    $self;
  }
}

#========================================

my $deps = build_dependency(my $db = RPM2->open_rpm_db
			   , sub {
			     ! /-debuginfo$/
			   });
# print Dumper($deps);


print join("\t", '#nreq', 'name', 'whatrequires...'), "\n";
foreach my PkgDep $dep (sort_by_nreqs($deps)) {
  my @whreqs = @{$dep->{whatrequires}};
  print join("\t", scalar @whreqs, $dep->{pkg}->name, @whreqs), "\n";
}

#========================================

sub sort_by_nreqs {
  my ($deps) = @_;
  sort {
    @{$a->{whatrequires}} <=> @{$b->{whatrequires}}
#      ||    keys(%{$a->{require}}) <=> keys(%{$b->{require}})
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
  my ($db, $filter_match) = @_;

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
    $dep->fixup;
  }

  foreach my PkgDep $dep (values %deps) {
    $dep->{whatrequires} = [map {
      $_->name
    } $db->find_by_requires($dep->{pkgName})];
  }

  \%deps;
}


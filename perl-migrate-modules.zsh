#!/bin/zsh

set -eu

emulate -L zsh

progFile=$0
function usage {
  ((! ARGC)) || print 1>&2 $*
  cat 1>&2 <<EOF
Usage: ${progFile:t} [--SUBCOMMAND] ARGS...

Available Subcommands are:

--migrate FROM_PERL  TO_PERL

--list-modules-from PERL

--install-modules-to PERL  MODULE_NAMES...
EOF
  exit 1
}

function die { echo 1>&2 $*; exit 1 }

#==========================

o_sudo=() sudo=()
o_cpm=()
o_xtrace=()
zparseopts -D -K S=o_sudo x=o_xtrace p=o_cpm

#==========================
binDir=$(cd $0:h && print $PWD)
xbDir=$binDir:h

function xb_perl {
   local spec=$1 dn
   if [[ -x $spec && $spec:t == perl && $spec:h:t == bin && -d $spec:h:t/lib ]]; then
	print $spec
   elif [[ -d $spec && -x $spec/bin/perl && -d $spec/lib ]]; then
	print $spec:a/bin/perl
   elif dn=$xbDir/perl-$spec; [[ -d $dn && -x $dn/bin/perl && -d $dn/lib ]]; then
	print $dn/bin/perl
   else
      die "Can't find acutal perl path for $spec"
   fi
}

#==========================
function cmd-migrate {
   ((ARGC == 2)) || usage "migrate FROM TO"
   local from=$1 to=$2
   local pkgs; pkgs=($(cmd-list-modules-from $from)) || return 1
   cmd-install-modules-to $to $pkgs
}
#==========================

# Stolen and splitted from plenv's migrate-modules
function cmd-list-modules-from {
   ((ARGC)) || usage "list-modules-from FROM_PERL"
   local from=$1
   local fromPerl; fromPerl=$(xb_perl $from) || return 1
   $fromPerl -MExtUtils::Installed -e 'for (ExtUtils::Installed->new(skip_cwd => 1)->modules) {next if /\APerl\z/; print $_, "\n";}'
}

function cmd-install-modules-to {
   ((ARGC)) || usage "install-modules-to TO_PERL"
   local to=$1; shift
   local toPerl; toPerl=$(xb_perl $to) || return 1
   local cpm=$toPerl:h/cpm cpanm=$toPerl:h/cpanm
   
   if (($#o_cpm)) && ! [[ -x $cpm ]]; then
        $sudo $cpanm App::cpm
   fi

   if  [[ -x $cpm ]]; then
	$sudo $cpm install -g "$@"
   elif  [[ -x $cpanm ]]; then
        $sudo $cpanm "$@"
   else
	die "Neither cpm nor cpanm found, stopped!"
   fi
}

#==========================
((!$#o_xtrace)) || set -x

((!$#o_sudo)) || sudo=(sudo)
#==========================

if ((ARGC)) && [[ $1 == --* ]]; then
  
  if cmd=cmd-${1#--}; (($+functions[$cmd])); then
     shift
  elif cmd=${1#--}; (($+functions[$cmd])); then
     shift
  else
     usage "No such subcommand: $1"
  fi
else
  cmd=cmd-migrate
fi

$cmd "$@"

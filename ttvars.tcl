#!/usr/bin/tclsh

# zsh 版は =\= とかの \ の事を忘れてた。zsh でも行けるはずだけど、面倒なので tcl で書き直し

package require cmdline

#========================================
set realScriptFn [file normalize [info script]]
set binDir [file dirname $realScriptFn]
set solverFn [file rootname $realScriptFn].prolog

set prologCmd [if {[info exists ::env(PROLOG_CMD)]} {
    set ::env(PROLOG_CMD)
} else {
    apply {{} {
        foreach cmd {gprolog swipl} {
            if {[auto_execok $cmd] ne ""} {
                return $cmd
            }
        }
    }}
}]

if {$prologCmd eq ""} {
    error "Can't find prolog interpreter!"
}

#========================================

proc list/prolog args {
    return "\[[join $args ,]\]"
}

proc literal2boolpairs args {
    set result []
    foreach expr $args {
        regsub <= $expr =< expr
        if {[regexp {^[_[:alpha:]][_[:alnum:]]*$} $expr]} {
            lappend result "\[$expr=1, $expr=0\]"
        } else {
            lappend result "\[$expr\]"
        }
    }
    set result
}

proc cmd_gprolog args {
    error "Not ported yet!"

    # 以下は元の zsh 版

    # To suppress compilation messages from consult, I use redirection here.
    # To use this, /dev/fd/3 should be available

    [[ -w /dev/fd/1 ]] || die /dev/fd/N is not available on your system.

    local script input
    input=$(list $argv)
    script=(
	"consult('$solver')"
	"open('/dev/fd/3',write,Out)"
	"set_output(Out)"
	"tt($input, write_tsv)"
    )
    [[ -n $o_verbose ]] || exec 2>/dev/null
    gprolog --init-goal "(${(j/,/)script};halt(0))" 3>&1 1>&2
}

proc cmd_swipl args {
    set script "tt([list/prolog {*}[literal2boolpairs {*}$args]], write_tsv)"
    set cmd [list swipl -f $::solverFn -g "($script;halt(0))"]
    if {$::opts(v)} {
        puts "# $cmd"
    }
    exec {*}$cmd >@ stdout 2>@ stderr
}

#========================================

array set opts [cmdline::getoptions ::argv {
    {v "verbose"}
}]

cmd_$prologCmd {*}$::argv

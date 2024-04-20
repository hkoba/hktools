#!/usr/bin/tclsh

package require cmdline
package require snit

snit::type jsonrpc_wrap {
    option -command {}
    option -verbose no
    option -in  stdin
    option -out stdout

    variable myPIPE

    method mainloop {} {
        vwait [myvar myPIPE]
    }

    constructor args {
        $self configurelist $args
        fileevent $options(-in) readable [list $self handle_input]
    }

    onconfigure -command list {
        set myPIPE [open [list | {*}$list 2>@ stderr ] w+]
        fconfigure $myPIPE -buffering none -translation crlf
        fileevent $myPIPE readable [list $self handle_response]
    }

    method handle_input {} {
        if {[gets $options(-in) json] < 0} {
            set myPIPE {}
            return
        }
        if {$options(-verbose)} {
            puts "# Content-Length: [string length $json]"
        }
        puts $myPIPE "Content-Length: [string length $json]"
        puts $myPIPE ""
        puts -nonewline $myPIPE $json
        if {$options(-verbose)} {
            puts ""
        }
    }

    method handle_response {} {
        puts [$self read_response $myPIPE]
        if {$options(-verbose)} {
            puts ""
        }
    }

    method read_response fh {
        if {[gets $fh header] < 0 || [gets $fh -] < 0} {
            close $fh
            set myPIPE {}
            return
        }
        lassign $header - bytes
        read $fh $bytes
    }
}

if {![info level] && [info script] eq $::argv0} {
    apply {{} {
        array set opts [cmdline::getKnownOptions ::argv {
            {v "verbose"}
        }]

        jsonrpc_wrap wrapper -verbose $opts(v) -command $::argv
        wrapper mainloop
    }}
}

#!/bin/zsh
zparseopts -D v=o_verbose C:=o_chdir

function msg {
    if (($#o_verbose)); then
	print "$@"
    fi
}

msg -n Starting Emacs.

# disown!
emacs </dev/null >&/dev/null &!

sock=/tmp/emacs$UID/server
until [[ -e $sock ]] && fuser -v $sock >&/dev/null; do
    msg -n .
    sleep 2;
done
msg Up!

if ((! ARGC)); then
  exit
fi

if (($#o_chdir)); then
    cd $o_chdir[-1]
fi

# if $@ is S-expression, prepend -e
if [[ $argv[1] = \(* && $argv[-1] = *\) ]]; then
    argv=(-e "$argv[@]")
fi

exec emacsclient "$argv[@]"

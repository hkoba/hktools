function Search_n_replace (old, new)
  execute "normal1G"
  while search(a:old, 'W')
    "getline('.') may work too.
    let cur  = getline(line('.'))
    let repl = substitute(cur, a:old, a:new, 'g')
    "Normal :echo do not displayed under -s(silent) mode, so I use perl
    perl print "REPLACE: ", join("->", map {[VIM::Eval($_)]->[1]} qw/cur repl/), "\n"
    call setline(line('.'), repl)
  endwhile
endfunction

function Search_n_delete (old)
  execute "normal1G"
  while search(a:old, 'W')
    let cur = getline(line('.'))
    execute "normal1D"
    perl print "DEL: ", join(" ", map {[VIM::Eval($_)]->[1]} qw/cur/), "\n"
  endwhile
endfunction

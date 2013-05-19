% -*- mode: prolog; coding: utf-8 -*-

% Simple util to make truth table.
% tested under gnu prolog and swi prolog.

%    ?- consult('tt.prolog').

%    | ?- tt([[y,n], [y,n]], writeln).
%    [y,y]
%    [n,y]
%    [y,n]
%    [n,n]
%    
%    no
%    | ?- tt([[y,n], [y,n], [y,n]], write_tsv).
%    y       y       y
%    n       y       y
%    y       n       y
%    n       n       y
%    y       y       n
%    n       y       n
%    y       n       n
%    n       n       n
%    
%    no

tt(List, Call) :-
    tt_q(List, [], Call), fail.

tt_q([], Result, Call) :-
    reverse(Result, Rev), call(Call, Rev).
tt_q([Hques|Tques], R, Call) :-
    tt_ans(Hques, Tques, R, Call).

tt_ans([Hans|Tans], Tques, R, Call) :-
    tt_q(Tques, [Hans | R], Call),
    !,
    (Tans = []; tt_ans(Tans, Tques, R, Call)).

writeln(X) :-
    write(X), nl.

write_tsv([]) :-
    nl, true.
write_tsv([H|T]) :-
    write(H), (T = []; write('\t')), write_tsv(T).

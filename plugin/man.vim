if exists('g:loaded_man')
    finish
endif
let g:loaded_man = 1

nno <silent> <space>o :<c-u>call man#toc#show()<cr>

" `:Man foo` doesn't work!{{{
"
"     :Man foo
"     man.vim: Vim(stag):E987: invalid return value from tagfunc~
"
" Check whether `$ man -w` can find the manpage:
"
"     $ man -w foo
"
" If the output is empty, try to reinstall the program `foo`; or at least its manpage.
"
" ---
"
" We had  this issue once with  `tig(1)`, because the manpage  was not correctly
" installed in `~/share/man`:
"
"     $ cd ~/share/man
"     $ tree
"     .~
"     ├── cat1~
"     │   ├── tig.1.gz~
"     │   └── youtube-dl.1.gz~
"     ├── index.db~
"     └── man1~
"         └── youtube-dl.1~
"}}}
com -bang -bar -range=0 -complete=customlist,man#complete -nargs=* Man
      \ if <bang>0
      \ |     set ft=man
      \ | else
      \ |     call man#excmd(v:count, v:count1, <q-mods>, <f-args>)
      \ | endif

augroup man
    au!
    au BufReadCmd man://* call expand('<amatch>')
        \ ->matchstr('man://\zs.*')
        \ ->man#shellcmd()
augroup END

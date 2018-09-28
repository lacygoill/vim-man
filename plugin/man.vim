if exists('g:loaded_man')
    finish
endif
let g:loaded_man = 1

" We can't access `v:count` from an Ex command!  So why referring to it in the rhs?{{{
"
" Don't forget that we can execute an Ex command from a mapping.
"
" `:Man` can be invoked with the normal  `K` command, because we install this in
" `~/.vim/plugged/vim-man/ftplugin/man.vim`:
"
"         nno  <buffer><nowait><silent>  K  :Man<cr>
"
" I think we could also have done:
"
"         set kp=:Man
"
" Anyway, if you press `123K` in normal mode, the rhs of the `:Man` command will
" have access to `v:count`.
"
" MWE:
"
"         :set kp=:Test
"         :com! -nargs=1  Test  echo v:count
"         123K
"             → 123
"}}}
" What's the purpose of `-range=0`?

com! -range=0 -complete=customlist,man#complete -nargs=* Man call
            \ man#open_page(v:count, v:count1, <q-mods>, <f-args>)

augroup man
    au!
    au BufReadCmd man://* call man#read_page(matchstr(expand('<amatch>'), 'man://\zs.*'))
augroup END

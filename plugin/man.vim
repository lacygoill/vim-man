if exists('g:loaded_man')
    finish
endif
let g:loaded_man = 1

" Why `<f-args>`?{{{
"
" `man#open_page()` must act differently depending on the number of arguments it
" received.
"}}}
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
"         :com!  Test  echo v:count
"         :nno  K  :<c-u>Test<cr>
"         123K
"             → 123
"
"                ┌ you need this attribute
"                │ because 'kp' will send the word under the cursor
"                │ as an argument to `:Test`
"                │
"         :com! -nargs=*  Test  echo v:count
"         :set kp=:Test
"         123K
"             → 123
"}}}
" What's the purpose of `-range=0`?{{{
"
" I don't know.
" To me, it seems unnecessary.
"
" Here the rationale given by the commit author:
"
"     But 'keywordprg' still calls ':Man' with a count prefixed.
"     So it must still accept a count in the line number position, ...
"
" Source:
"     https://github.com/neovim/neovim/pull/5203
"
" I don't understand why he says that:
"
"         :com! -count=1 -nargs=*  Test  echo <q-args>
"         :set kp=:Test
"         K on the word “hello”
"             → hello
"               ^
"               no count is sent as a prefix
"}}}
com! -bar -range=0 -complete=customlist,man#complete -nargs=*  Man
    \ call man#open_page(v:count, v:count1, <q-mods>, <f-args>)

augroup man
    au!
    au BufReadCmd man://* call man#read_page(matchstr(expand('<amatch>'), 'man://\zs.*'))
augroup END


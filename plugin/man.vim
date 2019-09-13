if exists('g:loaded_man')
    finish
endif
let g:loaded_man = 1

" TODO: Get rid of error message displayed when using the Nvim man plugin:{{{
"
"     $ man git-credential-cache
"     man.vim: command error (7) man -w git-credential-cac: No manual entry for git-credential-cac~
"
" Notice how the man page name has been truncated (`he` is missing at the end).
" It's already truncated when this autocmd is run:
"
"     /usr/local/share/nvim/runtime/plugin/man.vim:14
"
" The issue is due to `man(1)` which truncates the name of the file.
"
"     $ MANPAGER='vim -R +":set ft=man" -' man git-credential-cache
"     :echo bufname('%')
"     man://git-credential-cac(1)~
"                             ^
"                             `he` is missing
"
" https://unix.stackexchange.com/q/541556/289772
"}}}

" Purpose:{{{
"
" Search a keyword in all man pages.
" Open the first matching page.
" Cycle through the other ones by pressing `]p`, and `[p`.
"}}}
com! -bar -nargs=1 ManZsh  call man#zsh#main(<q-args>)

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
"         123~
"
"                ┌ you need this attribute
"                │ because 'kp' will send the word under the cursor
"                │ as an argument to `:Test`
"                │
"         :com! -nargs=*  Test  echo v:count
"         :set kp=:Test
"         123K
"         123~
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
"         hello~
"         ^
"         no count is sent as a prefix~
"}}}
com! -bar -range=0 -complete=customlist,man#complete -nargs=*  Man
    \ call man#open_page(v:count, v:count1, <q-mods>, <f-args>)

augroup man
    au!
    au BufReadCmd man://* call man#read_page(matchstr(expand('<amatch>'), 'man://\zs.*'))
augroup END

" When we  open a  manpage, `$MAN_PN`  is set  with the name  of the  page (ex:
" man(1)); we can test its value to know  if Vim has been launched to read a man
" page.
if !empty($MAN_PN)
    augroup manpage
        au!
        " Why do we use an autocmd, instead of just `setl man` directly?{{{
        "
        " Because it would be too soon, the buffer wouldn't be loaded yet.
        " We have to wait for the standard input to have been read completely.
        "}}}
        au StdinReadPost * setl ft=man
    augroup END
endif


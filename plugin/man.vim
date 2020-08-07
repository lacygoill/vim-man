if exists('g:loaded_man')
    finish
endif
let g:loaded_man = 1

" TODO: When you'll re-implement the Nvim man plugin, make sure to use `$MAN_PN` to get the name of the man page.{{{
"
" Atm, in `/usr/local/share/nvim/runtime/autoload/man.vim`:
"
"     " Guess the ref from the heading (which is usually uppercase, so we cannot
"     " know the correct casing, cf. `man glDrawArraysInstanced`).
"     let ref = getline(1)->matchstr('^[^)]\+)')->substitute(' ', '_', 'g')
"
" On Linux, one can get the same info via `$MAN_PN`.
" Using this variable is more reliable then reading the heading in the man page.
" For example, in the man page for `git-credential-cache(1)`, the heading is:
"
"     GIT-CREDENTIAL-CAC(1)             Git Manual             GIT-CREDENTIAL-CAC(1)
"                       ^
"                       ✘
"
" Notice how the name is truncated; `HE` is missing.
" This is just because the author of the man page truncated the name of the command:
"
"     $ zcat /usr/share/man/man1/git-credential-cache.1.gz | sed -n '10p'
"     .TH "GIT\-CREDENTIAL\-CAC" "1" "08/17/2019" "Git 2\&.23\&.0" "Git Manual"~
"                             ^
"                             ✘
"
" Besides, if you  try to guess the name  of the man page from  the heading, you
" lose  the original  case, because  the heading  is usually  all in  uppercase,
" regardless of the original case used in the command name.
"
" When you'll re-implement the Nvim man plugin, make sure to fix that:
"
"     " remove this
"     let ref = getline(1)->matchstr('^[^)]\+)')->substitute(' ', '_', 'g')
"
"     " add this
"     let ref = $MAN_PN
"}}}

" Purpose:{{{
"
" Search a keyword in all man pages.
" Open the first matching page.
" Cycle through the other ones by pressing `]p`, and `[p`.
"}}}
com -bar -nargs=1 ManZsh  call man#zsh#main(<q-args>)

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
"     nno <buffer><nowait><silent> K :<c-u>Man<cr>
"
" I think we could also have done:
"
"     setl kp=:Man
"
" Anyway, if you press `123K` in normal mode, the rhs of the `:Man` command will
" have access to `v:count`.
"
" MWE:
"
"     :com Test echo v:count
"     :nno K :<c-u>Test<cr>
"     123K
"     123~
"
"           ┌ you need this attribute
"           │ because 'kp' will send the word under the cursor
"           │ as an argument to `:Test`
"           │
"     :com -nargs=* Test echo v:count
"     :setl kp=:Test
"     123K
"     123~
"}}}
" What's the purpose of `-range=0`?{{{
"
" I don't know.
" To me, it seems unnecessary.
"
" Here is the rationale given by the commit author:
"
" >     But 'keywordprg' still calls ':Man' with a count prefixed.
" >     So it must still accept a count in the line number position, ...
"
" Source: https://github.com/neovim/neovim/pull/5203
"
" I don't understand why he says that:
"
"     :com -count=1 -nargs=* Test echo <q-args>
"     :set kp=:Test
"     K on the word “hello”
"     hello~
"     ^
"     no count is sent as a prefix~
"}}}
com -bar -range=0 -complete=customlist,man#complete -nargs=* Man
    \ call man#open_page(v:count, v:count1, <q-mods>, <f-args>)

augroup man | au!
    au BufReadCmd man://* call expand('<amatch>')->matchstr('man://\zs.*')->man#read_page()
augroup END

" When we  open a  manpage, `$MAN_PN`  is set  with the name  of the  page (ex:
" man(1)); we can test its value to know  if Vim has been launched to read a man
" page.
if !empty($MAN_PN)
    augroup manpage | au!
        " Why do we use an autocmd, instead of just `setl man` directly?{{{
        "
        " Because it would be too soon, the buffer wouldn't be loaded yet.
        " We have to wait for the standard input to have been read completely.
        "}}}
        au StdinReadPost * setl ft=man
    augroup END
endif


if exists('g:loaded_man')
    finish
endif
let g:loaded_man = 1

nno <silent> <space>o :<c-u>call man#toc#show()<cr>

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

com! -range=0 -complete=customlist,man#complete -nargs=* Man call
            \ man#open_page(v:count, v:count1, <q-mods>, <f-args>)

augroup man
    au!
    au BufReadCmd man://* call man#read_page(matchstr(expand('<amatch>'), 'man://\zs.*'))
augroup END
if exists('b:did_ftplugin') || &filetype !=# 'man'
    finish
endif
let b:did_ftplugin = 1

" When I open a man page, I immediately want to be able to cycle through
" options with `;` and `,`.
let g:motion_to_repeat = ']o'

" maximize the window, the 1st time we load a man page
wincmd _

" My original man ftplugin {{{
"
" Set the name of the scratch buffer; ex:    man(1)
" otherwise, we would have [Scratch] as a placeholder
if empty(bufname('%'))
    file $MAN_PN
endif

" Why the `if` condition?
" Suppose we open a man buffer:
"
"         $ man bash
"
" The command `file $MAN_PN` names it using the value environment variable:
"
"         $MAN_PN    ex: bash(1)
"
" Then we look for a reference, and click on it.
" A new man buffer is loaded, and the command would again try to name the new
" buffer with the same name `$MAN_PN`.
" It would give an error because a buffer with this name already exists.
" Besides, there's no need to rename the subsequent buffers, somehow they're
" automatically correctly named when opened from Vim (instead of the shell).

" Options {{{
"
" We can't give the value `wipe` to 'bufhidden'.
" Indeed, after clicking on a reference in a man buffer, the original buffer
" would be wiped out. We couldn't get back to it with `C-T`.

setlocal noswapfile
setlocal buftype=nofile
setlocal nobuflisted

" Kind of help buffer
setlocal nomodifiable
setlocal readonly

" Formatting
setlocal nolist
setlocal ignorecase

"}}}
" Mappings {{{

nmap  <buffer><nowait><silent>  <cr>  <c-]>
nmap  <buffer><nowait><silent>  <bs>  <c-t>

nno  <buffer><nowait><silent>  q  :<c-u>exe my_lib#quit()<cr>

nno  <buffer><nowait><silent>  [H  :<c-u>call <sid>search_syntax('heading', '[H', 0)<cr>
nno  <buffer><nowait><silent>  ]H  :<c-u>call <sid>search_syntax('heading', ']H', 1)<cr>
nno  <buffer><nowait><silent>  [o  :<c-u>call <sid>search_syntax('option', '[o', 0)<cr>
nno  <buffer><nowait><silent>  ]o  :<c-u>call <sid>search_syntax('option', ']o', 1)<cr>
nno  <buffer><nowait><silent>  [r  :<c-u>call <sid>search_syntax('ref', '[r', 0)<cr>
nno  <buffer><nowait><silent>  ]r  :<c-u>call <sid>search_syntax('ref', ']r', 1)<cr>
nno  <buffer><nowait><silent>  [s  :<c-u>call <sid>search_syntax('subheading', '[s', 0)<cr>
nno  <buffer><nowait><silent>  ]s  :<c-u>call <sid>search_syntax('subheading', ']s', 1)<cr>

xno  <buffer><nowait><silent>  [H  :<c-u>call <sid>search_syntax('heading', '[H', 0, 1)<cr>
xno  <buffer><nowait><silent>  ]H  :<c-u>call <sid>search_syntax('heading', ']H', 1, 1)<cr>
xno  <buffer><nowait><silent>  [o  :<c-u>call <sid>search_syntax('option', '[o', 0, 1)<cr>
xno  <buffer><nowait><silent>  ]o  :<c-u>call <sid>search_syntax('option', ']o', 1, 1)<cr>
xno  <buffer><nowait><silent>  [r  :<c-u>call <sid>search_syntax('ref', '[r', 0, 1)<cr>
xno  <buffer><nowait><silent>  ]r  :<c-u>call <sid>search_syntax('ref', ']r', 1, 1)<cr>
xno  <buffer><nowait><silent>  [s  :<c-u>call <sid>search_syntax('subheading', '[s', 0, 1)<cr>
xno  <buffer><nowait><silent>  ]s  :<c-u>call <sid>search_syntax('subheading', ']s', 1, 1)<cr>

ono  <buffer><nowait><silent>  [H  :norm V[Hj<cr>
ono  <buffer><nowait><silent>  ]H  :norm V]Hk<cr>
ono  <buffer><nowait><silent>  [o  :norm v[o<cr>
ono  <buffer><nowait><silent>  ]o  :norm v]o<cr>
ono  <buffer><nowait><silent>  [r  :norm v[r<cr>
ono  <buffer><nowait><silent>  ]r  :norm v]r<cr>
ono  <buffer><nowait><silent>  [s  :norm V[sj<cr>
ono  <buffer><nowait><silent>  ]s  :norm V]sk<cr>

let s:keyword2pattern = {
                        \ 'heading'    : '^[a-z][a-z -]*[a-z]$',
                        \ 'option'     : '^\s\+\zs\%(+\|-\)\S\+',
                        \ 'ref'        : '\f\+([1-9][a-z]\=)',
                        \ 'subheading' : '^\s\{3\}\zs[a-z][a-z -]*[a-z]$',
                        \ }

fu! s:search_syntax(keyword, mapping, fwd, ...) abort
    let g:motion_to_repeat = a:mapping

    if a:0
        norm! gv
    endif

    norm! m'

    call search(s:keyword2pattern[a:keyword], 'W'.(a:fwd ? '' : 'b'))
endfu

"}}}
"
"}}}

let s:pager = !exists('b:man_sect')

if s:pager
    call man#init_pager()
endif

setl buftype=nofile
setl noswapfile
setl bufhidden=hide
setl nomodified
setl readonly
setl nomodifiable
setl noexpandtab
setl tabstop=8
setl softtabstop=8
setl shiftwidth=8

setl nonumber
setl norelativenumber
setl foldcolumn=0
setl colorcolumn=0
setl nolist
setl nofoldenable

nno  <buffer><nowait><silent>  <c-]>  :Man<cr>
nno  <buffer><nowait><silent>  K      :Man<cr>
nno  <buffer><nowait><silent>  <c-t>  :call man#pop_tag()<cr>

" I frequently hit `p` by accident. It raises the error:
"
"     E21: Cannot make changes, 'modifiable' is off
nno  <buffer><nowait><silent>  p  <nop>

" FIXME:{{{
"
" From: :h undo_ftplugin
"
"     When the user does ":setfiletype xyz" the effect of the previous filetype
"     should be undone.  Set the b:undo_ftplugin variable to the commands that will
"     undo the settings in your filetype plugin.  Example: >
"
"         let b:undo_ftplugin = "setl fo< com< tw< commentstring<"
"             \ . "| unlet b:match_ignorecase b:match_words b:match_skip"
"
"     Using ":setl" with "<" after the option name resets the option to its
"     global value.  That is mostly the best way to reset the option value.
"
"     This does require removing the "C" flag from 'cpoptions' to allow line
"     continuation, as mentioned above |use-cpo-save|.
"
"     For undoing the effect of an indent script, the b:undo_indent variable should
"     be set accordingly.
"
" Also, from `:lh undo_ftplugin`:
"
"     The line to set b:undo_ftplugin is for when the filetype is set to another
"     value.  In that case you will want to undo your preferences.  The
"     b:undo_ftplugin variable is exed as a command. Watch out for characters
"     with a special meaning inside a string, such as a backslash.
"
" We should do this for all our filetype plugins.
"
" Why is `b:undo_ftplugin` set to an empty string here?
" If we put nothing inside, then why bother defining the variable?
"
" }}}

let b:undo_ftplugin = ''

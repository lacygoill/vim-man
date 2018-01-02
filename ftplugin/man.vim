if exists('b:did_ftplugin') || &filetype !=# 'man'
    finish
endif
let b:did_ftplugin = 1

" When I open a man page, I immediately want to be able to cycle through
" options with `;` and `,`.
let g:motion_to_repeat = ']s'

" maximize the window, the 1st time we load a man page
wincmd _

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

setl buftype=nofile
setl noswapfile
setl nobuflisted
setl bufhidden=hide

setl nomodified
setl noexpandtab
setl tabstop=8
setl softtabstop=8
setl shiftwidth=8

setl nonumber
setl norelativenumber
setl foldcolumn=0
setl colorcolumn=0
setl nofoldenable

" Kind of help buffer
setl nomodifiable
setl readonly

" Formatting
setl nolist
setl ignorecase

"}}}
" Mappings {{{

nmap  <buffer><nowait><silent>  <cr>  <c-]>
nmap  <buffer><nowait><silent>  <bs>  <c-t>

nno  <buffer><nowait><silent>  q  :<c-u>call lg#quit()<cr>

nno  <buffer><nowait><silent>  [H  :<c-u>call <sid>search_syntax('heading', '[H', 0)<cr>
nno  <buffer><nowait><silent>  ]H  :<c-u>call <sid>search_syntax('heading', ']H', 1)<cr>
nno  <buffer><nowait><silent>  [s  :<c-u>call <sid>search_syntax('option', '[s', 0)<cr>
nno  <buffer><nowait><silent>  ]s  :<c-u>call <sid>search_syntax('option', ']s', 1)<cr>
nno  <buffer><nowait><silent>  [r  :<c-u>call <sid>search_syntax('ref', '[r', 0)<cr>
nno  <buffer><nowait><silent>  ]r  :<c-u>call <sid>search_syntax('ref', ']r', 1)<cr>
nno  <buffer><nowait><silent>  [S  :<c-u>call <sid>search_syntax('subheading', '[S', 0)<cr>
nno  <buffer><nowait><silent>  ]S  :<c-u>call <sid>search_syntax('subheading', ']S', 1)<cr>

xno  <buffer><nowait><silent>  [H  :<c-u>call <sid>search_syntax('heading', '[H', 0, 1)<cr>
xno  <buffer><nowait><silent>  ]H  :<c-u>call <sid>search_syntax('heading', ']H', 1, 1)<cr>
xno  <buffer><nowait><silent>  [s  :<c-u>call <sid>search_syntax('option', '[s', 0, 1)<cr>
xno  <buffer><nowait><silent>  ]s  :<c-u>call <sid>search_syntax('option', ']s', 1, 1)<cr>
xno  <buffer><nowait><silent>  [r  :<c-u>call <sid>search_syntax('ref', '[r', 0, 1)<cr>
xno  <buffer><nowait><silent>  ]r  :<c-u>call <sid>search_syntax('ref', ']r', 1, 1)<cr>
xno  <buffer><nowait><silent>  [S  :<c-u>call <sid>search_syntax('subheading', '[S', 0, 1)<cr>
xno  <buffer><nowait><silent>  ]S  :<c-u>call <sid>search_syntax('subheading', ']S', 1, 1)<cr>

ono  <buffer><nowait><silent>  [H  :norm V[Hj<cr>
ono  <buffer><nowait><silent>  ]H  :norm V]Hk<cr>
ono  <buffer><nowait><silent>  [s  :norm v[s<cr>
ono  <buffer><nowait><silent>  ]s  :norm v]s<cr>
ono  <buffer><nowait><silent>  [r  :norm v[r<cr>
ono  <buffer><nowait><silent>  ]r  :norm v]r<cr>
ono  <buffer><nowait><silent>  [S  :norm V[Sj<cr>
ono  <buffer><nowait><silent>  ]S  :norm V]Sk<cr>

let s:keyword2pattern = {
\                         'heading'    : '^[a-z][a-z -]*[a-z]$',
\                         'option'     : '^\s\+\zs\%(+\|-\)\S\+',
\                         'ref'        : '\f\+([1-9][a-z]\=)',
\                         'subheading' : '^\s\{3\}\zs[a-z][a-z -]*[a-z]$',
\                       }

fu! s:search_syntax(keyword, mapping, fwd, ...) abort
    let g:motion_to_repeat = a:mapping

    if a:0
        norm! gv
    endif

    norm! m'

    call search(s:keyword2pattern[a:keyword], 'W'.(a:fwd ? '' : 'b'))
endfu

let s:pager = !exists('b:man_sect')

if s:pager
    call man#init_pager()
endif

nno  <buffer><nowait><silent>  <c-]>  :Man<cr>
nno  <buffer><nowait><silent>  K      :Man<cr>
nno  <buffer><nowait><silent>  <c-t>  :call man#pop_tag()<cr>

" I frequently hit `p` by accident. It raises the error:
"
"     E21: Cannot make changes, 'modifiable' is off
nno  <buffer><nowait><silent>  p  <nop>

" Teardown {{{1

let b:undo_ftplugin =         get(b:, 'undo_ftplugin', '')
\                     .(empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
\                     ."
\                          setl bufhidden<
\                        | setl buftype<
\                        | setl colorcolumn<
\                        | setl foldcolumn<
\                        | setl ignorecase<
\                        | setl nobuflisted<
\                        | setl noexpandtab<
\                        | setl nofoldenable<
\                        | setl nolist<
\                        | setl nomodifiable<
\                        | setl nomodified<
\                        | setl nonumber<
\                        | setl norelativenumber<
\                        | setl noswapfile<
\                        | setl readonly<
\                        | setl shiftwidth<
\                        | setl softtabstop<
\                        | setl tabstop<
\                        | unlet! b:man_sect
\                        | exe 'nunmap <buffer> <c-]>'
\                        | exe 'nunmap <buffer> <cr>'
\                        | exe 'nunmap <buffer> <bs>'
\                        | exe 'nunmap <buffer> K'
\                        | exe 'nunmap <buffer> <c-t>'
\                        | exe 'nunmap <buffer> p'
\                        | exe 'nunmap <buffer> q'
\                        | exe 'nunmap <buffer> [H'
\                        | exe 'nunmap <buffer> ]H'
\                        | exe 'nunmap <buffer> [s'
\                        | exe 'nunmap <buffer> ]s'
\                        | exe 'nunmap <buffer> [r'
\                        | exe 'nunmap <buffer> ]r'
\                        | exe 'nunmap <buffer> [S'
\                        | exe 'nunmap <buffer> ]S'
\                        | exe 'xunmap <buffer> [H'
\                        | exe 'xunmap <buffer> ]H'
\                        | exe 'xunmap <buffer> [s'
\                        | exe 'xunmap <buffer> ]s'
\                        | exe 'xunmap <buffer> [r'
\                        | exe 'xunmap <buffer> ]r'
\                        | exe 'xunmap <buffer> [S'
\                        | exe 'xunmap <buffer> ]S'
\                        | exe 'ounmap <buffer> [H'
\                        | exe 'ounmap <buffer> ]H'
\                        | exe 'ounmap <buffer> [s'
\                        | exe 'ounmap <buffer> ]s'
\                        | exe 'ounmap <buffer> [r'
\                        | exe 'ounmap <buffer> ]r'
\                        | exe 'ounmap <buffer> [S'
\                        | exe 'ounmap <buffer> ]S'
\                      "

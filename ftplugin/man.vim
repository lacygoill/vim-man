if exists('b:did_ftplugin') || &filetype !=# 'man'
    finish
endif
let b:did_ftplugin = 1

" My original man ftplugin "{{{
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

" Options "{{{
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
" Mappings "{{{

nmap <buffer> <silent> <CR>  <C-]>
nmap <buffer> <silent> <BS>  <C-T>

nno <buffer> <silent> q    :<C-U>call myfuncs#quit()<CR>

nno <buffer> <nowait> <silent> [h    :<C-U>call <SID>search_syntax('heading', '[h', 1)<CR>
nno <buffer> <nowait> <silent> ]h    :<C-U>call <SID>search_syntax('heading', ']h', 0)<CR>
nno <buffer> <nowait> <silent> [o    :<C-U>call <SID>search_syntax('option', '[o', 1)<CR>
nno <buffer> <nowait> <silent> ]o    :<C-U>call <SID>search_syntax('option', ']o', 0)<CR>
nno <buffer> <nowait> <silent> [r    :<C-U>call <SID>search_syntax('ref', '[r', 1)<CR>
nno <buffer> <nowait> <silent> ]r    :<C-U>call <SID>search_syntax('ref', ']r', 0)<CR>
nno <buffer> <nowait> <silent> [s    :<C-U>call <SID>search_syntax('subheading', '[s', 1)<CR>
nno <buffer> <nowait> <silent> ]s    :<C-U>call <SID>search_syntax('subheading', ']s', 0)<CR>

xno <buffer> <nowait> <silent> [h    :<C-U>call <SID>search_syntax('heading', '[h', 1, 1)<CR>
xno <buffer> <nowait> <silent> ]h    :<C-U>call <SID>search_syntax('heading', ']h', 0, 1)<CR>
xno <buffer> <nowait> <silent> [o    :<C-U>call <SID>search_syntax('option', '[o', 1, 1)<CR>
xno <buffer> <nowait> <silent> ]o    :<C-U>call <SID>search_syntax('option', ']o', 0, 1)<CR>
xno <buffer> <nowait> <silent> [r    :<C-U>call <SID>search_syntax('ref', '[r', 1, 1)<CR>
xno <buffer> <nowait> <silent> ]r    :<C-U>call <SID>search_syntax('ref', ']r', 0, 1)<CR>
xno <buffer> <nowait> <silent> [s    :<C-U>call <SID>search_syntax('subheading', '[s', 1, 1)<CR>
xno <buffer> <nowait> <silent> ]s    :<C-U>call <SID>search_syntax('subheading', ']s', 0, 1)<CR>

ono <buffer> <nowait> <silent> [h    :norm V[hj<CR>
ono <buffer> <nowait> <silent> ]h    :norm V]hk<CR>
ono <buffer> <nowait> <silent> [o    :norm v[o<CR>
ono <buffer> <nowait> <silent> ]o    :norm v]o<CR>
ono <buffer> <nowait> <silent> [r    :norm v[r<CR>
ono <buffer> <nowait> <silent> ]r    :norm v]r<CR>
ono <buffer> <nowait> <silent> [s    :norm V[sj<CR>
ono <buffer> <nowait> <silent> ]s    :norm V]sk<CR>

let s:keyword2pattern = {
                        \ 'heading'    : '^[a-z][a-z -]*[a-z]$',
                        \ 'option'     : '^\s\+\zs\%(+\|-\)\S\+',
                        \ 'ref'        : '\f\+([1-9][a-z]\=)',
                        \ 'subheading' : '^\s\{3\}\zs[a-z][a-z -]*[a-z]$',
                        \ }

fu! s:search_syntax(keyword, mapping, back, ...) abort
    let g:motion_to_repeat = a:mapping

    if a:0
        norm! gv
    endif

    norm! m'

    call search(s:keyword2pattern[a:keyword], 'W'.(a:back ? 'b' : ''))
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

nno <silent> <buffer> <C-]>      :Man<CR>
nno <silent> <buffer> K          :Man<CR>
nno <silent> <buffer> <C-T>      :call man#pop_tag()<CR>

" I frequently hit `p` by accident. It raises the error:
"
"     E21: Cannot make changes, 'modifiable' is off
nno <silent> <buffer> p <nop>

" When I open a man page, I immediately want to be able to cycle between
" options with `;` and `,`.
let g:motion_to_repeat = ']o'

" FIXME:"{{{
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

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

nno <buffer> <silent> o    :<C-U>call <SID>search_syntax_element(0, 'option')<CR>
nno <buffer> <silent> O    :<C-U>call <SID>search_syntax_element(1, 'option')<CR>
nno <buffer> <silent> r    :<C-U>call <SID>search_syntax_element(0, 'ref')<CR>
nno <buffer> <silent> R    :<C-U>call <SID>search_syntax_element(1, 'ref')<CR>
nno <buffer> <silent> s    :<C-U>call <SID>search_syntax_element(0, 'heading')<CR>
nno <buffer> <silent> S    :<C-U>call <SID>search_syntax_element(1, 'heading')<CR>

fu! s:syntax_under_cursor() abort
    return synIDattr(synID(line('.'), col('.'), 1), 'name')
endfu

" FIXME:
"
" Make our mapping moving the cursor to the next reference in a man page more
" robust. Currrently, it skips some references when they are separated by
" commas or newlines. Maybe we should tell the `search()` function to look for
" a next word OR the pattern `<\k+>(\d+)` (+ the condition that the latter has
" the right syntax group).

fu! s:search_syntax_element(backward, to_look_for) abort
    let original_pos       = getpos('.')
    let initial_element    = s:syntax_under_cursor()
    let next_element       = ''

    let to_look_for        = a:to_look_for == 'heading'
                           \ ?    ['manSubHeading', 'manSectionHeading']
                           \ :    a:to_look_for == 'option'
                           \      ?    ['manOptionDesc', 'manLongOptionDesc']
                           \      :    a:to_look_for == 'ref'
                           \           ?    ['manReference']
                           \           :    ''

    let identical_sequence = 1
    let found_sth          = 1

    while found_sth && (!count(to_look_for, next_element) || identical_sequence)

        " Go on searching as long as:"{{{
        "
        "        - we found something the last time
        "
        "          Because, if in the last iteration, no word was found, then
        "          there's no word after the current cursor position any more.
        "
        "                            AND
        "
        "        - the element under the cursor is not what we are looking for
        "
        "                  OR
        "
        "          it is what we are looking for, but it's part of a sequence of
        "          identical elements;
        "
        "          we don't want the cursor to move to the next word inside an
        "          identical sequence;
        "          we want it to move to the next word outside of it
"}}}

        let found_sth    = search('\<\k\+', 'W' . (a:backward ? 'b' : ''))
        " let found_sth    = search((to_look_for[0] ==# 'manReference' ? '\<\k\+(\d)' : '\<\k\+'), 'W' . (a:backward ? 'b' : ''))
        let next_element = s:syntax_under_cursor()

        " Why do we create the variable `identical_sequence` and update it inside"{{{
        " the loop?
        " Why don't we get rid of it, and put the test:
        "
        "         next_element == initial_element
        "
        " … in the `:while` declaration?
        " Because then, it would make sure that EACH found word is different than
        " the initial one.
        " But that's not what we want. We just want to make sure that between
        " the final found word and our initial position, AT LEAST ONE found word
        " was different than the initial one.
"}}}

        if next_element != initial_element
            let identical_sequence = 0
        endif
    endwhile

    " If the cursor ended on some text which is not what we were looking for
    " (reached the very beginning / end of the buffer),
    " move it back where it was.

    if !count(to_look_for, s:syntax_under_cursor())
        call setpos('.', original_pos)
    endif
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

if s:pager
    nno <silent> <buffer> <nowait> q :q<CR>
else
    nno <silent> <buffer> <nowait> q <C-W>c
endif

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

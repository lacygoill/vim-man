if exists('b:did_ftplugin') || &filetype !=# 'man'
  finish
endif
let b:did_ftplugin = 1

let s:pager = !exists('b:man_sect')

if s:pager
  call man#init_pager()
endif

setlocal buftype=nofile
setlocal noswapfile
setlocal bufhidden=hide
setlocal nomodified
setlocal readonly
setlocal nomodifiable
setlocal noexpandtab
setlocal tabstop=8
setlocal softtabstop=8
setlocal shiftwidth=8

setlocal nonumber
setlocal norelativenumber
setlocal foldcolumn=0
setlocal colorcolumn=0
setlocal nolist
setlocal nofoldenable

if !exists('g:no_plugin_maps') && !exists('g:no_man_maps')
  nnoremap <silent> <buffer> <C-]>      :Man<CR>
  nnoremap <silent> <buffer> K          :Man<CR>
  nnoremap <silent> <buffer> <C-T>      :call man#pop_tag()<CR>
  if s:pager
    nnoremap <silent> <buffer> <nowait> q :q<CR>
  else
    nnoremap <silent> <buffer> <nowait> q <C-W>c
  endif
endif

" Source:
" https://github.com/neovim/neovim/pull/4449#issuecomment-237290098
fu! s:create_toc() abort
    let toc = []
    for lnum in range(1, line('$'))
        let c = match(getline(lnum), '\S\zs')
        if c != -1 && synIDattr(synID(lnum, c, 0), 'name') =~? '\v%(heading|title)$'
            let text = substitute(getline(lnum), '\s\+', ' ', 'g')
            call add(toc, {'bufnr': bufnr('%'), 'lnum': lnum, 'text': text})
        endif
    endfor

    " Why do we call `setloclist()` 2 times? "{{{
    "
    " To set the title of the location window, we must pass the dictionary
    " `{'title': 'TOC' }` as a fourth argument to `setloclist()`.
    " But when we pass a fourth argument, the list passed as a 2nd argument is
    " ignored. No item in this list will populate the location list.
    "
    " So, the purpose of the first call to `setloclist()` is to populate the
    " location list.
    " The purpose of the second call is to set the title of the location
    " window.
    "
    " In the 2nd call, the empty list and the `a` flag are not important.
    " We could replace them with resp. any list and the `r` flag, for example.
    " But we choose the empty list `[]` and the `a` flag, because it makes the
    " code more readable. Indeed, since we only set the title of the window,
    " and nothing in the list changes, it's as if we were adding/appending an
    " empty list.
    "
"}}}

    call setloclist(0, toc)
    call setloclist(0, [], 'a', { 'title': 'TOC' })
    lwindow
endfu

nno <silent> <buffer> <leader>t    :<C-U>call <SID>create_toc()<CR>


if get(g:, 'ft_man_folding_enable', 0)
  setlocal foldenable
  setlocal foldmethod=indent
  setlocal foldnestmax=1
endif

" FIXME:"{{{
"
" From: :h undo_ftplugin
"
"     When the user does ":setfiletype xyz" the effect of the previous filetype
"     should be undone.  Set the b:undo_ftplugin variable to the commands that will
"     undo the settings in your filetype plugin.  Example: >
"
"         let b:undo_ftplugin = "setlocal fo< com< tw< commentstring<"
"             \ . "| unlet b:match_ignorecase b:match_words b:match_skip"
"
"     Using ":setlocal" with "<" after the option name resets the option to its
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
"     b:undo_ftplugin variable is executed as a command. Watch out for characters
"     with a special meaning inside a string, such as a backslash.
"
" We should do this for all our filetype plugins.
"
" Why is `b:undo_ftplugin` set to an empty string here?
" If we put nothing inside, then why bother defining the variable?
"
" }}}

let b:undo_ftplugin = ''

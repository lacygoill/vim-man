let s:man_cmd = 'man 2>/dev/null'

" Read this (new concept of outline):
" https://github.com/neovim/neovim/pull/5169

fu! man#open_page(count, count1, mods, ...) abort "{{{1
    if a:0 > 2
        call s:error('too many arguments')
        return
    elseif a:0 == 0
        let ref = &ft ==# 'man' ? expand('<cWORD>') : expand('<cword>')
        if empty(ref)
            call s:error('no identifier under cursor')
            return
        endif
    elseif a:0 ==# 1
        let ref = a:1
    else

        " We have 2 optional arguments:
        "
        "     a:1    3
        "     a:2    printf
        "
        " We combine them to create a reference:
        "
        "     printf(3)

        let ref = a:2.'('.a:1.')'
    endif

    try
        let [sect, name] = man#extract_sect_and_name_ref(ref)
        if a:count ==# a:count1
            " v:count defaults to 0 which is a valid section, and v:count1 defaults to
            " 1, also a valid section. If they are equal, count explicitly set.
            let sect = string(a:count)
        endif
        let [sect, name, path] = s:verify_exists(sect, name)
    catch
        call s:error(v:exception)
        return
    endtry

    call s:push_tag()

    let bufname = 'man://' . name . (empty(sect) ? '' : '('.sect.')')

    if a:mods !~# 'tab' && s:find_man()
        noautocmd exe 'sil edit '.fnameescape(bufname)
    else
        noautocmd exe 'sil '.a:mods.' split '.fnameescape(bufname)
    endif

    let b:man_sect = sect
    call s:read_page(path)
endfu

fu! man#read_page(ref) abort "{{{1
    try
        let [sect, name]             = man#extract_sect_and_name_ref(a:ref)
        let [b:man_sect, name, path] = s:verify_exists(sect, name)
    catch
        " call to s:error() is unnecessary
        return
    endtry
    call s:read_page(path)
endfu

fu! s:read_page(path) abort "{{{1
    setl modifiable noreadonly
    sil keepj %d_

    " Force MANPAGER=cat to ensure Vim is not recursively invoked (by man-db).
    " http://comments.gmane.org/gmane.editors.vim.devel/29085
    " Respect $MANWIDTH, or default to window width.

    let cmd  = 'env MANPAGER=cat'.(empty($MANWIDTH) ? ' MANWIDTH='.winwidth(0) : '')
    let cmd .= ' '.s:man_cmd.' '.shellescape(a:path)
    sil put =system(cmd)

    " Remove all backspaced characters.
    exe "sil keepp keepj %s/.\b//ge"

    while getline(1) =~# '^\s*$'
        sil keepj 1d_
    endwhile
    setl filetype=man
endfu

fu! man#extract_sect_and_name_ref(ref) abort "{{{1
" attempt to extract the name and sect out of 'name(sect)'
" otherwise just return the largest string of valid characters in ref

    " try ':Man -pandoc' with this disabled.
    if a:ref[0] ==# '-'
        throw 'manpage name cannot start with ''-'''
    endif

    let ref = matchstr(a:ref, '[^()]\+([^()]\+)')
    if empty(ref)
        let name = matchstr(a:ref, '[^()]\+')
        if empty(name)
            throw 'manpage reference cannot contain only parentheses'
        endif
        return [get(b:, 'man_default_sects', ''), name]
    endif

    let left = split(ref, '(')

    " see ':Man 3X curses' on why tolower.

    return [tolower(split(left[1], ')')[0]), left[0]]
endfu

fu! s:get_path(sect, name) abort "{{{1

    if empty(a:sect)
        let path = system(s:man_cmd.' -w '.shellescape(a:name))

        if path !~# '^\/'
            throw 'no manual entry for '.a:name
        endif

        return path
    endif

    " '-s' flag handles:
    "
    "     - tokens like 'printf(echo)'
    "     - sections starting with '-'
    "     - 3pcap section (found on macOS)
    "     - commas between sections (for section priority)

    return system(s:man_cmd.' -w '.shellescape(a:sect).' '.shellescape(a:name))
endfu

fu! s:verify_exists(sect, name) abort "{{{1

    let path = s:get_path(a:sect, a:name)
    if path !~# '^\/'
        let path = s:get_path(get(b:, 'man_default_sects', ''), a:name)

        if path !~# '^\/'
            let path = s:get_path('', a:name)
        endif
    endif

    " We need to extract the section from the path because sometimes
    " the actual section of the manpage is more specific than the section
    " we provided to `man`. Try ':Man 3 App::CLI'.
    " Also on linux, it seems that the name is case insensitive. So if one does
    " ':Man PRIntf', we still want the name of the buffer to be 'printf' or
    " whatever the correct capitalization is.

    let path = path[:len(path)-2]

    return s:extract_sect_and_name_path(path) + [path]
endfu

" push_tag {{{1

let s:tag_stack = []
fu! s:push_tag() abort
    let s:tag_stack += [{
                        \ 'buf':  bufnr('%'),
                        \ 'lnum': line('.'),
                        \ 'col':  col('.'),
                        \ }]
endfu

fu! man#pop_tag() abort "{{{1
    if !empty(s:tag_stack)
        let tag = remove(s:tag_stack, -1)
        exe 'sil' tag['buf'].'buffer'
        call cursor(tag['lnum'], tag['col'])
    endif
endfu

fu! s:extract_sect_and_name_path(path) abort "{{{1
" extracts the name and sect out of 'path/name.sect'

    let tail = fnamemodify(a:path, ':t')

    " valid extensions
    if a:path =~# '\v\.%([glx]z|bz2|lzma|Z)$'
        let tail = fnamemodify(tail, ':r')
    endif

    let sect = matchstr(tail, '\.\zs[^.]\+$')
    let name = matchstr(tail, '^.\+\ze\.')

    return [sect, name]
endfu

fu! s:find_man() abort "{{{1
    if &ft ==# 'man'
        return 1
    elseif winnr('$') ==# 1
        return 0
    endif

    let thiswin = winnr()

    while 1
        wincmd w
        if &ft ==# 'man'
            return 1
        elseif winnr() ==# thiswin
            return 0
        endif
    endwhile
endfu

fu! s:error(msg) abort "{{{1
    redraw
    echohl ErrorMsg
    echon 'man.vim: '.a:msg
    echohl None
endfu

" complete {{{1
let s:mandirs = join(split(system(s:man_cmd.' -w'), ':\|\n'), ',')

" FIXME:
" doesn't work if we prefix `:Man` with a modifier such as `:tab` or `:vert`.
" Add support for a possible modifier.

" see man#extract_sect_and_name_ref on why tolower(sect)
fu! man#complete(arglead, cmdline, _p) abort
    let args    = split(a:cmdline)
    let arglead = a:arglead
    let N       = len(args)

    if N > 3

        " There can be:
        "
        "     1 token (Man)
        "     2       (Man <section number>)
        "     3       (Man <section number> command)
        "
        " So, there shouldn't be more than 3 tokens.

        return

    elseif N ==# 1
        let [name, sect] = ['', '']

    elseif arglead =~# '^[^()]\+([^()]*$'

        " cursor (|) is at:
        "
        "     :Man printf(|
        "     :Man 1 printf(|

        let tmp  = split(arglead, '(')
        let name = tmp[0]
        let sect = tolower(get(tmp, 1, ''))

    elseif args[1] !~# '^[^()]\+$'

        " cursor (|) is at:
        "
        "     :Man 3() |
        "     :Man (3|
        "     :Man 3() pri|
        "     :Man 3() pri |

        return

    elseif N ==# 2
        if empty(arglead)
            " cursor (|) is at ':Man 1 |'
            let name = ''
            let sect = tolower(args[1])

        else
            " cursor (|) is at ':Man pri|'
            if arglead =~# '\/'
                " if the name is a path, complete files
                return glob(arglead.'*', 0, 1)
            endif
            let name = arglead
            let sect = ''
        endif

    elseif arglead !~# '^[^()]\+$'
        " cursor (|) is at ':Man 3 printf |' or ':Man 3 (pr)i|'
        return

    else
        " cursor (|) is at ':Man 3 pri|'
        let name = arglead
        let sect = tolower(args[1])
    endif

    " We remove duplicates incase the same manpage in different languages was found.
    return uniq(sort(map(globpath(s:mandirs,'man?/'.name.'*.'.sect.'*', 0, 1),
    \                    { i,v -> s:format_candidate(v, sect) }
    \                   ),
    \                'i')
    \          )
endfu

fu! s:format_candidate(path, sect) abort "{{{1
    " invalid extensions
    if a:path =~# '\v\.%(pdf|in)$'
        return
    endif

    let [sect, name] = s:extract_sect_and_name_path(a:path)

    if sect ==# a:sect
        return name
    elseif sect =~# a:sect.'.\+$'
        " We include the section if the user provided section is a prefix
        " of the actual section.
        return name.'('.sect.')'
    endif
endfu

fu! man#init_pager() abort "{{{1
    " Set the buffer to be modifiable, otherwise the next commands
    " cause an error:
    "
    "     Error detected while processing function man#init_pager:
    "     E21: Cannot make changes, 'modifiable' is off

    setl modifiable

    " Remove all backspaced characters.
    exe "sil keepp keepj %s/.\b//ge"
    if getline(1) =~# '^\s*$'
        sil keepj 1delete _
    else
        keepj 1
    endif
    " This is not perfect. See `man glDrawArraysInstanced`. Since the title is
    " all caps it is impossible to tell what the original capitilization was.
    let ref = tolower(matchstr(getline(1), '^\S\+'))
    try
        let b:man_sect = man#extract_sect_and_name_ref(ref)[0]
    catch
        let b:man_sect = ''
    endtry
    exe 'sil file man://'.fnameescape(ref)
endfu

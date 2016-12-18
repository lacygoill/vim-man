let s:man_cmd = 'man 2>/dev/null'

let s:man_find_arg = '-w'

fu! man#open_page(count, count1, mods, ...) abort
    if a:0 > 2
        call s:error('too many arguments')
        return
    elseif a:0 == 0
        let ref = &filetype ==# 'man' ? expand('<cWORD>') : expand('<cword>')
        if empty(ref)
            call s:error('no identifier under cursor')
            return
        endif
    elseif a:0 ==# 1
        let ref = a:1
    else
        " Combine the name and sect into a manpage reference so that all
        " verification/extraction can be kept in a single function.
        " If a:2 is a reference as well, that is fine because it is the only
        " reference that will match.
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
    let bufname = 'man://'.name.(empty(sect)?'':'('.sect.')')
    if a:mods !~# 'tab' && s:find_man()
        noautocmd exe 'sil edit' fnameescape(bufname)
    else
        noautocmd exe 'sil' a:mods 'split' fnameescape(bufname)
    endif
    let b:man_sect = sect
    call s:read_page(path)
endfu

fu! man#read_page(ref) abort
    try
        let [sect, name] = man#extract_sect_and_name_ref(a:ref)
        let [b:man_sect, name, path] = s:verify_exists(sect, name)
    catch
        " call to s:error() is unnecessary
        return
    endtry
    call s:read_page(path)
endfu

fu! s:read_page(path) abort
    setl modifiable noreadonly
    sil keepj %delete _
    " Force MANPAGER=cat to ensure Vim is not recursively invoked (by man-db).
    " http://comments.gmane.org/gmane.editors.vim.devel/29085
    " Respect $MANWIDTH, or default to window width.
    let cmd  = 'env MANPAGER=cat'.(empty($MANWIDTH) ? ' MANWIDTH='.winwidth(0) : '')
    let cmd .= ' '.s:man_cmd.' '.shellescape(a:path)
    sil put =system(cmd)
    " Remove all backspaced characters.
    exe 'sil keepp keepj %s/.\b//ge'
    while getline(1) =~# '^\s*$'
        sil keepj 1delete _
    endwhile
    setl filetype=man
endfu

" attempt to extract the name and sect out of 'name(sect)'
" otherwise just return the largest string of valid characters in ref
fu! man#extract_sect_and_name_ref(ref) abort
    if a:ref[0] ==# '-' " try ':Man -pandoc' with this disabled.
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
    " TODO(nhooyr) Not sure if this is portable across OSs
    " but I have not seen a single uppercase section.
    return [tolower(split(left[1], ')')[0]), left[0]]
endfu

fu! s:get_path(sect, name) abort
    if empty(a:sect)
        let path = system(s:man_cmd.' '.s:man_find_arg.' '.shellescape(a:name))
        if path !~# '^\/'
            throw 'no manual entry for '.a:name
        endif
        return path
    endif
    " '-s' flag handles:
    "   - tokens like 'printf(echo)'
    "   - sections starting with '-'
    "   - 3pcap section (found on macOS)
    "   - commas between sections (for section priority)
    return system(s:man_cmd.' '.s:man_find_arg.' -s '.shellescape(a:sect).' '.shellescape(a:name))
endfu

fu! s:verify_exists(sect, name) abort
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

let s:tag_stack = []

fu! s:push_tag() abort
    let s:tag_stack += [{
                \ 'buf':  bufnr('%'),
                \ 'lnum': line('.'),
                \ 'col':  col('.'),
                \ }]
endfu

fu! man#pop_tag() abort
    if !empty(s:tag_stack)
        let tag = remove(s:tag_stack, -1)
        exe 'sil' tag['buf'].'buffer'
        call cursor(tag['lnum'], tag['col'])
    endif
endfu

" extracts the name and sect out of 'path/name.sect'
fu! s:extract_sect_and_name_path(path) abort
    let tail = fnamemodify(a:path, ':t')
    if a:path =~# '\.\%([glx]z\|bz2\|lzma\|Z\)$' " valid extensions
        let tail = fnamemodify(tail, ':r')
    endif
    let sect = matchstr(tail, '\.\zs[^.]\+$')
    let name = matchstr(tail, '^.\+\ze\.')
    return [sect, name]
endfu

fu! s:find_man() abort
    if &filetype ==# 'man'
        return 1
    elseif winnr('$') ==# 1
        return 0
    endif
    let thiswin = winnr()
    while 1
        wincmd w
        if &filetype ==# 'man'
            return 1
        elseif thiswin ==# winnr()
            return 0
        endif
    endwhile
endfu

fu! s:error(msg) abort
    redraw
    echohl ErrorMsg
    echon 'man.vim: ' a:msg
    echohl None
endfu

let s:mandirs = join(split(system(s:man_cmd.' '.s:man_find_arg), ':\|\n'), ',')

" see man#extract_sect_and_name_ref on why tolower(sect)
fu! man#complete(lead, line, _pos) abort
    let args = split(a:line)
    let l = len(args)
    if l > 3
        return
    elseif l ==# 1
        let name = ''
        let sect = ''
    elseif a:lead =~# '^[^()]\+([^()]*$'
        " cursor (|) is at ':Man printf(|' or ':Man 1 printf(|'
        " The later is is allowed because of ':Man pri<TAB>'.
        " It will offer 'priclass.d(1m)' even though section is specified as 1.
        let tmp = split(a:lead, '(')
        let name = tmp[0]
        let sect = tolower(get(tmp, 1, ''))
    elseif args[1] !~# '^[^()]\+$'
        " cursor (|) is at ':Man 3() |' or ':Man (3|' or ':Man 3() pri|'
        " or ':Man 3() pri |'
        return
    elseif l ==# 2
        if empty(a:lead)
            " cursor (|) is at ':Man 1 |'
            let name = ''
            let sect = tolower(args[1])
        else
            " cursor (|) is at ':Man pri|'
            if a:lead =~# '\/'
                " if the name is a path, complete files
                " TODO(nhooyr) why does this complete the last one automatically
                return glob(a:lead.'*', 0, 1)
            endif
            let name = a:lead
            let sect = ''
        endif
    elseif a:lead !~# '^[^()]\+$'
        " cursor (|) is at ':Man 3 printf |' or ':Man 3 (pr)i|'
        return
    else
        " cursor (|) is at ':Man 3 pri|'
        let name = a:lead
        let sect = tolower(args[1])
    endif
    " We remove duplicates incase the same manpage in different languages was found.
    return uniq(sort(map(globpath(s:mandirs,'man?/'.name.'*.'.sect.'*', 0, 1), 's:format_candidate(v:val, sect)'), 'i'))
endfu

fu! s:format_candidate(path, sect) abort
    if a:path =~# '\.\%(pdf\|in\)$' " invalid extensions
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

fu! man#init_pager() abort
    " Remove all backspaced characters.
    exe 'sil keepp keepj %s/.\b//ge'
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

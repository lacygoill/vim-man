vim9script

# TODO: Consolidate all `b:` variables into a single one big dictionary.
# Wait for Vim9 to support `var dict.key = value`.

# TODO: Extract this script into a separate plugin.
# Rationale: It's no  longer specific  to man.   It can work  in other  types of
# buffers now (help, markdown, terminal).

# Init {{{1

import InTerminalBuffer from 'lg.vim'

# a few patterns for help files

#     123. Some header     *some tag*
const HEADER = '^\d\+\.\s.*\*$'
#     SOME HEADLINE    *some-tag*
const HEADLINE = '^[A-Z][-A-Z0-9 .()_]*\%(\s\+\*\|$\)'
#     12.34 Some sub-header~
const SUBHEADER1 = '^\d\+\.\d\+\s.*\~$'
#     some sub-header
#     ---------------
const SUBHEADER2 = '\%x01$'
#     Some sub-sub-header~
const SUBSUBHEADER = '^[A-Z].*\~$'

# Interface {{{1
def man#toc#show() #{{{2
    if index(['man', 'help', 'markdown'], &ft) == -1
        && !InTerminalBuffer()
        return
    endif
    if !exists('b:_toc')
        # `''` is for a terminal buffer
        b:_toc = {'': [], '0': [], '1': [], '2': [], '3': [], '4': [], '5': []}
        b:_toc_foldlevel_max = {'': 0, 'man': 1, 'help': 3, 'markdown': 5}[&ft]
        b:_toc_foldlevel = b:_toc_foldlevel_max
        if &ft == 'man'
            CacheTocMan()
        elseif &ft == 'markdown'
            CacheTocMarkdown()
        elseif &ft == 'help'
            CacheTocHelp()
        elseif &ft == ''
            CacheTocTerminal()
        endif
    endif
    var statusline = &ls == 2 || &ls == 1 && winnr('$') >= 2 ? 1 : 0
    var tabline = &stal == 2 || &stal == 1 && tabpagenr('$') >= 2 ? 1 : 0
    var borders = 2 # top/bottom
    # Is `popup_menu()` ok with a list of dictionaries?{{{
    #
    # Yes, see `:h popup_create-arguments`.
    # Although, it expects dictionaries with the keys `text` and `props`.
    # But we use dictionaries with the keys `text` and `lnum`.
    # IOW, we abuse the feature which lets us use text properties in a popup.
    #}}}
    var id = b:_toc[string(b:_toc_foldlevel)]
        ->popup_menu(#{
            line: 2,
            col: &columns,
            pos: 'topright',
            scrollbar: false,
            highlight: 'Normal',
            border: [1, 1, 1, 1],
            borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
            # TODO: Will it look good in a window which is not maximized?
            # Should we replace `&lines` with `winheight(0)` and `&columns` with `winwidth(0)`?
            # Look at how we've computed the geometry of the popup in `fuzzyhelp.vim`.
            minheight: &lines - (&ch + statusline + tabline + borders),
            maxheight: &lines - (&ch + statusline + tabline + borders),
            minwidth: &columns / 3,
            maxwidth: &columns / 3,
            filter: Filter,
            callback: Callback,
            })
    Highlight(id)
    JumpToRelevantLine(id)
    # can't set  the title before  jumping to  the relevant line,  otherwise the
    # indicator in the title might be wrong
    SetTitle(id)
enddef
#}}}1
# Core {{{1
def CacheTocMan() #{{{2
    # Caching the toc is necessary to get good performance.{{{
    #
    # Without caching, when you press `H`, `L`,  `H`, `L`, ... quickly for a few
    # seconds, there is some lag if you then try to move with `j` and `k`.
    # This can only be perceived in big man pages like ffmpeg-all.
    #}}}
    var lines = getline(2, line('$') - 1)
        ->map({i, v -> #{lnum: i + 2, text: v}})

    if b:_toc_foldlevel == 0
        b:_toc['0'] = filter(lines, {_, v -> v.text =~ '^\S'})
    else
        b:_toc['1'] = filter(lines, {_, v -> v.text =~ '^\%( \{3\}\)\=\S'})
    endif
enddef

def CacheTocMarkdown() #{{{2
    var lines = getline(1, '$')
        ->map({i, v -> #{lnum: i + 1, text: v}})

    var lastlnum = line('$')
    # prepend a marker (`C-a`) in front of lines underlined with `---`
    map(lines, {i, v ->
        i < lastlnum - 1
        && lines[i + 1].text =~ '^-\+$'
        && v.text =~ '\S'
        ? extend(v, #{text: "\x01" .. v.text})
        : v
        })

    var pat1 = '^#\{1,' .. (b:_toc_foldlevel + 1) .. '}\s*[^ \t#]'
    var pat2 = b:_toc_foldlevel == 0 ? '^=\+$' : '^[-=]\+$'
    b:_toc[b:_toc_foldlevel] = copy(lines)
        # keep only title lines
        ->filter({i, v -> v.text =~ pat1
            ||
            i < lastlnum - 1
            && lines[i + 1].text =~ pat2
            && v.text =~ '\S'
            })
        # remove noise (`###`), and indent
        ->map({_, v -> extend(v,
            #{text: substitute(v.text, '^#\+\s*\|^\%x01',
                {m -> repeat('   ', m[0] =~ '^\%x01' ? 1 : count(m[0], '#') - 1)},
                '')}
            )})
enddef

def CacheTocHelp() #{{{2
    var lines = getline(1, '$')
        ->map({i, v -> #{lnum: i + 1, text: v}})

    # append a marker on underlined sub-headers
    #
    #     some sub-header
    #     ---------------
    var len = len(lines)
    map(lines, {i, v -> i < len - 1
        # there must be a tag at the end
        && v.text =~ '\*$'
        && lines[i + 1].text =~ '^-\+$'
        ? extend(v, #{text: v.text .. "\x01"})
        : v
        })

    # TODO: Include all tag lines (`\*$`).
    # Yeah, I know; this is going to give a shitload of results.
    # But that shouldn't be  an issue if you tweak `H` and `L`  so that they can
    # decrease / increase one level of folding.
    var pat = {
        '0': HEADER,
        '1': HEADER .. '\|' .. HEADLINE,
        '2': HEADER .. '\|' .. HEADLINE .. '\|' .. SUBHEADER1 .. '\|' .. SUBHEADER2,
        '3': HEADER .. '\|' .. HEADLINE .. '\|' .. SUBHEADER1 .. '\|' .. SUBHEADER2 .. '\|' .. SUBSUBHEADER,
        }[string(b:_toc_foldlevel)]
    filter(lines, {i, v -> v.text =~ pat})

    # indent appropriately
    map(lines, {_, v -> v.text =~ SUBHEADER1
        .. '\|' .. SUBHEADER2
        .. '\|' .. HEADLINE
        ? extend(v, #{text: '   ' .. v.text})
        : v.text =~ '\~$'
        ? extend(v, #{text: '      ' .. v.text})
        : v
        })
    # remove noise
    map(lines, {_, v -> extend(v,
        #{text: substitute(v.text, '\t.*\|[~\x01]$', '', '')}
        )})
    b:_toc[b:_toc_foldlevel] = lines
enddef

def CacheTocTerminal() #{{{2
# Support a  terminal scrollback  buffer (either  in a  Vim terminal  buffer, or
# captured  via  tmux's `capture-pane`).   The  toc  should display  each  shell
# command executed so far as an entry.

    b:_toc[b:_toc_foldlevel] = getline(1, '$')
        ->map({i, v -> #{lnum: i + 1, text: v}})
        ->filter({_, v -> v.text =~ '^٪'})
enddef

def SetTitle(id: number) #{{{2
    var lastlnum = line('$', id)
    var newtitle = printf(' %*d/%d (%d)',
        len(lastlnum), line('.', id),
        lastlnum,
        (b:_toc_foldlevel + 1))
    # In a terminal buffer, the foldlevel indicator is useless.  There is only 1 level.
    if &ft == ''
        newtitle = substitute(newtitle, ' (\d\+)$', '', '')
    endif
    popup_setoptions(id, #{title: newtitle})
enddef

def JumpToRelevantLine(id: number) #{{{2
    var lnum = line('.')
    var firstline = b:_toc[b:_toc_foldlevel]
        ->copy()
        ->filter({_, v -> v.lnum <= lnum})
        ->len()
    if firstline == 0
        return
    endif
    win_execute(id, 'norm! ' .. firstline .. 'Gzz')
enddef

def Highlight(id: number) #{{{2
    if &ft == 'man'
        # Why not just setting the syntax to `man`?{{{
        #
        # Indeed, this would work for the most part:
        #
        #     win_execute(id, 'set syntax=man')
        #
        # But the highlighting would be still wrong on the first and last line.
        #}}}
        # How does the Neovim plugin achieve the same result?{{{
        #
        # It uses the toc lines to set the location list.
        #
        # Besides, the qf filetype plugin installs this autocmd:
        #
        #     " /usr/local/share/nvim/runtime/ftplugin/qf.vim
        #     augroup qf_toc
        #       autocmd!
        #       autocmd Syntax <buffer> call s:setup_toc()
        #     augroup END
        #
        # Which could be replaced with:
        #
        #     au Syntax <buffer> ++once call s:setup_toc()
        #
        # When the qf filetype plugin is sourced, 'syntax' has not been set yet;
        # when it happens right after, the autocmd calls `s:setup_toc()`:
        #
        #     function! s:setup_toc() abort
        #       if get(w:, 'quickfix_title') !~# '\<TOC$' || &syntax != 'qf'
        #         return
        #       endif
        #
        #       let list = getloclist(0)
        #       if empty(list)
        #         return
        #       endif
        #
        #       let bufnr = list[0].bufnr
        #       setlocal modifiable
        #       silent %delete _
        #       call setline(1, map(list, 'v:val.text'))
        #       setlocal nomodifiable nomodified
        #       let &syntax = getbufvar(bufnr, '&syntax')
        #     endfunction
        #
        # The latter makes the buffer temporarily modifiable to remove the noise
        # (file path, lnum, col, ...), and keep only the (sub)headings.
        # And  at the  end,  it resets  the  syntax  to the  one  of the  buffer
        # associated to  the location window  (here `man`;  but it could  be any
        # other syntax, like `help`).
        #
        # ---
        #
        # About `<buffer>`:
        #
        #     au Syntax <buffer> call s:setup_toc()
        #               ^------^
        #
        # It doesn't matter what a "regular"  pattern is matched against (here a
        # syntax name like "python" or "ruby").
        # `<buffer>` is always matched against a buffer number, and matches only
        # if that number is  the one of the current buffer  (here, the one where
        # the 'syntax' option has just been set, triggering the Syntax event).
        #}}}
        matchadd('manSectionHeading', '^\S.*', 10, -1, #{window: id})
        matchadd('manSubHeading', '^\s\{3}\S.*', 10, -1, #{window: id})
    elseif &ft == 'help'
        matchadd('helpHeadline', '^\S.*', 10, -1, #{window: id})
        matchadd('helpHeader', '^   \S.*', 10, -1, #{window: id})
    elseif &ft == 'markdown'
        matchadd('markdownHeader', '.*', 10, -1, #{window: id})
    endif
enddef

def Filter(id: number, key: string): bool #{{{2
    if index(['j', 'k', 'g', 'G', "\<c-d>", "\<c-u>"], key) >= 0
        win_execute(id, 'norm! ' .. (key == 'g' ? 'gg' : key))
        SetTitle(id)
        return true

    # when we press `p`, print the selected line (useful when it's truncated)
    elseif key == 'p'
        echo b:_toc[b:_toc_foldlevel][line('.', id) - 1].text
        return true

    elseif key == 'q'
        popup_close(id, -1)
        return true

    elseif key == 'H' && b:_toc_foldlevel > 0
        || key == 'L' && b:_toc_foldlevel < b:_toc_foldlevel_max

        if key == 'H'
            b:_toc_foldlevel = max([0, get(b:, '_toc_foldlevel') - 1])
        else
            b:_toc_foldlevel = min([b:_toc_foldlevel_max, get(b:, '_toc_foldlevel') + 1])
        endif

        # must be saved before we reset the popup contents

        # TODO: Is `^\S` always right?{{{
        #
        # ---
        #
        # Also, review  each location whe  we've used `search()`;  check whether
        # it's  reliable  (e.g. does  it  still  work  as  expected in  case  of
        # duplicate titles?).
        #}}}
        var prevheading = win_execute(id, 'echo search("^\\S", "bcW")->getline()')
            ->trim("\<c-j>")

        if b:_toc[b:_toc_foldlevel]->empty()
            if &ft == 'man'
                CacheTocMan()
            elseif &ft == 'markdown'
                CacheTocMarkdown()
            elseif &ft == 'help'
                CacheTocHelp()
            endif
        endif
        # TODO: If the contents of the TOC does not change (happens sometimes in
        # Vim help  files), continue increasing/decreasing until  it changes, or
        # it's no longer possible to increase/decrease.
        popup_settext(id, b:_toc[string(b:_toc_foldlevel)])
        SetTitle(id)

        var pat = '^\V' .. escape(prevheading, '\') .. '\m$'
        win_execute(id, [printf('search(%s)', string(pat)), 'norm! zz'])
        return true
    endif
    return popup_filter_menu(id, key)
enddef

def Callback(id: number, choice: number) #{{{2
    if choice == -1
        return
    endif
    var lnum = get(b:_toc[b:_toc_foldlevel], choice - 1)->get('lnum')
    if lnum == 0
        return
    endif
    cursor(lnum, 1)
    norm! zvzt
enddef


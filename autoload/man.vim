vim9script

if exists('g:autoloaded_man')
    finish
endif
g:autoloaded_man = 1

var localfile_arg = true  # Always use -l if possible. #6683

# TODO:
#
# `p` could be used to preview a reference to another manpage in a popup window.
# `]r` and `]o` could be used to jump to the next reference or option.

# TODO: Implement an ad-hoc annotations feature?
# They could be saved persistently in files, and displayed via popup windows.

# TODO:  Assimilate the plugin; i.e. understand it, simplify it, ...

# TODO: Read all the todos/fixmes in our old implementation.
# Check whether some of them are still relevant in the new implementation.
# Also, check  whether we've lost some  code/feature, which we should  copy from
# the old code.

# TODO: Implement `:Mangrep`:
# https://github.com/vim-utils/vim-man#about-mangrep

# TODO: When we run `:Man`, the name of the file in the statusline is inconsistent with `$ man`.{{{
#
# Example:
#
#     $ man man
#     man(1)
#     ^----^
#       ✔
#
#     :Man man
#     man.1
#     ^---^
#       ✘
#
#     $ man ls
#     ls(1)
#     ^---^
#       ✔
#
#     :Man ls
#     ls.1.gz
#     ^-----^
#        ✘
#
# The Neovim plugin has the same issue.
#}}}

# Interface {{{1
def man#shellcmd(ref: string) #{{{2
    var sect: string
    var name: string
    var page: string
    try
        [sect, name] = Extract_sect_and_name_ref(ref)
        var path = Verify_exists(sect, name)
        [sect, name] = Extract_sect_and_name_path(path)
        page = Get_page(path)
    catch
        Error(v:exception)
        return
    endtry
    b:man_sect = sect
    Put_page(page)
enddef

def man#excmd(count: number, count1: number, mods: string, ...fargs: list<string>) #{{{2
    var ref: string
    if len(fargs) > 2
        Error('too many arguments')
        return
    elseif len(fargs) == 0
        ref = &filetype == 'man' ? expand('<cWORD>') : expand('<cword>')
        if empty(ref)
            Error('no identifier under cursor')
            return
        endif
    elseif len(fargs) == 1
        ref = fargs[0]
    else
        # Combine the name and sect into a manpage reference so that all
        # verification/extraction can be kept in a single function.
        # If `farg[1]` is  a reference as well,  that is fine because  it is the
        # only reference that will match.
        ref = fargs[1] .. '(' .. fargs[0] .. ')'
    endif
    var sect: string
    var name: string
    try
        [sect, name] = Extract_sect_and_name_ref(ref)
        if count == count1
            # `v:count` defaults to 0 which is a valid section, and `v:count1` defaults to
            # 1, also a valid section.  If they are equal, count explicitly set.
            sect = string(count)
        endif
        var path = Verify_exists(sect, name)
        [sect, name] = Extract_sect_and_name_path(path)
    catch
        Error(v:exception)
        return
    endtry

    var buf = bufnr('%')
    var save_tfu = &l:tagfunc
    try
        setl tagfunc=man#goto_tag
        var target = name .. '(' .. sect .. ')'
        if mods !~ 'tab' && Find_man()
            execute 'silent keepalt tag ' .. target
        else
            execute 'silent keepalt ' .. mods .. ' stag ' .. target
        endif
    # E987: invalid return value from tagfunc
    # *raised when you ask for an unknown man page*
    catch /E987:/
        Error(v:exception)
    finally
        setbufvar(buf, '&tagfunc', save_tfu)
    endtry

    b:man_sect = sect
enddef

def man#complete(arg_lead: string, cmd_line: string, _p: any): list<string> #{{{2
    var args = split(cmd_line)
    var cmd_offset = index(args, 'Man')
    if cmd_offset > 0
        # Prune all arguments up to :Man itself. Otherwise modifier commands like
        # :tab, :vertical, etc. would lead to a wrong length.
        args = args[cmd_offset:]
    endif
    var l = len(args)
    var name: string
    var sect: string
    if l > 3
        return []
    elseif l == 1
        name = ''
        sect = ''
    elseif arg_lead =~ '^[^()]\+([^()]*$'
        # cursor (|) is at `:Man printf(|` or `:Man 1 printf(|`
        # The later is is allowed because of `:Man pri<TAB>`.
        # It will offer `priclass.d(1m)` even though section is specified as 1.
        var tmp = split(arg_lead, '(')
        name = tmp[0]
        sect = get(tmp, true, '')->tolower()
        return Complete(sect, '', name)
    elseif args[1] !~ '^[^()]\+$'
        # cursor (|) is at `:Man 3() |` or `:Man (3|` or `:Man 3() pri|`
        # or `:Man 3() pri |`
        return []
    elseif l == 2
        if empty(arg_lead)
            # cursor (|) is at `:Man 1 |`
            name = ''
            sect = tolower(args[1])
        else
            # cursor (|) is at `:Man pri|`
            if arg_lead =~ '\/'
                # if the name is a path, complete files
                # TODO(nhooyr) why does this complete the last one automatically
                return glob(arg_lead .. '*', false, true)
            endif
            name = arg_lead
            sect = ''
        endif
    elseif arg_lead !~ '^[^()]\+$'
        # cursor (|) is at `:Man 3 printf |` or `:Man 3 (pr)i|`
        return []
    else
        # cursor (|) is at `:Man 3 pri|`
        name = arg_lead
        sect = tolower(args[1])
    endif
    return Complete(sect, sect, name)
enddef

def man#goto_tag(pattern: string, _f: any, _i: any): list<dict<string>> #{{{2
    var sect: string
    var name: string
    [sect, name] = Extract_sect_and_name_ref(pattern)

    var paths = Get_paths(sect, name, true)
    var structured: list<dict<string>>

    for path in paths
        var n = Extract_sect_and_name_path(path)[1]
        structured += [#{name: n, path: path}]
    endfor

    if &cscopetag
        # return only a single entry so we work well with :cstag (#11675)
        structured = structured[:0]
    endif

    return map(structured, {_, entry -> #{
        name: entry.name,
        filename: 'man://' .. entry.path,
        cmd: 'keepj norm! 1G'
        }})
enddef

def man#foldexpr(): string #{{{2
    if indent(v:lnum) == 0 && getline(v:lnum) =~ '\S'
    || indent(v:lnum) == 3
        return '>1'
    endif
    return '='
enddef

def man#init_pager() #{{{2
    # clear message:  "-stdin-" 123L, 456B
    echo ''
    au VimEnter * keepj norm! 1GzR
    # https://github.com/neovim/neovim/issues/6828
    var og_modifiable = &modifiable
    setl modifiable

    if getline(1) =~ '^\s*$'
        :sil keepj 1d _
    endif
    Highlight_on_cursormoved()
    OpenFolds()

    # Guess the ref from the heading (which is usually uppercase, so we cannot
    # know the correct casing, cf. `man glDrawArraysInstanced`).
    var ref = getline(1)
        ->matchstr('^[^)]\+)')
        ->substitute(' ', '_', 'g')
    try
        b:man_sect = Extract_sect_and_name_ref(ref)[0]
    catch
        b:man_sect = ''
    endtry
    if -1 == match(bufname('%'), 'man:\/\/')  # Avoid duplicate buffers, E95.
        execute 'silent file man://' .. fnameescape(ref)->tolower()
    endif

    &l:modifiable = og_modifiable
enddef

def man#JumpToRef(fwd = true) #{{{2
    # regex used by the `manReference` syntax group
    var pat = '[^()[:space:]]\+([0-9nx][a-z]*)'
    var flags = fwd ? 'W' : 'bW'
    search(pat, flags)
enddef
#}}}1
# Core {{{1
# Main {{{2
def Extract_sect_and_name_ref(ref: string): list<string> #{{{3
# attempt to extract the name and sect out of `name(sect)`
# otherwise just return the largest string of valid characters in ref

    if ref[0] == '-' # try `:Man -pandoc` with this disabled
        throw 'manpage name cannot start with ''-'''
    endif
    var _ref = matchstr(ref, '[^()]\+([^()]\+)')
    if empty(_ref)
        var name = matchstr(ref, '[^()]\+')
        if empty(name)
            throw 'manpage reference cannot contain only parentheses'
        endif
        return ['', name]
    endif
    var left = split(_ref, '(')
    # see `:Man 3X curses` on why `tolower()`.
    # TODO(nhooyr) Not sure if this is portable across OSs
    # but I have not seen a single uppercase section.
    return [split(left[1], ')')[0]->tolower(), left[0]]
enddef

def Extract_sect_and_name_path(path: string): list<string> #{{{3
# Extracts the name/section from the `path/name.sect`, because sometimes the actual section is
# more specific than what we provided to `man` (try `:Man 3 App::CLI`).
# Also on linux, name seems to be case-insensitive. So for `:Man PRIntf`, we
# still want the name of the buffer to be `printf`.

    var tail = fnamemodify(path, ':t')
    if path =~ '\.\%([glx]z\|bz2\|lzma\|Z\)$' # valid extensions
        tail = fnamemodify(tail, ':r')
    endif
    var sect = matchstr(tail, '\.\zs[^.]\+$')
    var name = matchstr(tail, '^.\+\ze\.')
    return [sect, name]
enddef

def Verify_exists(sect: string, name: string): string #{{{3
# Verify_exists attempts to find the path to a manpage
# based on the passed section and name.
#
# 1. If the passed section is empty, b:man_default_sects is used.
# 2. If manpage could not be found with the given sect and name,
#    then another attempt is made with b:man_default_sects.
# 3. If it still could not be found, then we try again without a section.
# 4. If still not found but $MANSECT is set, then we try again with $MANSECT
#    unset.
#
# This function is careful to avoid duplicating a search if a previous
# step has already done it. i.e if we use b:man_default_sects in step 1,
# then we don't do it again in step 2.
    var _sect = sect
    if empty(_sect)
        _sect = get(b:, 'man_default_sects', '')
    endif
    try
        return Get_path(_sect, name)
    catch /^command error \%x28/
    endtry
    if !get(b:, 'man_default_sects', '')->empty()
        && _sect != b:man_default_sects
        try
            return Get_path(b:man_default_sects, name)
        catch /^command error \%x28/
        endtry
    endif
    if !empty(_sect)
        try
            return Get_path('', name)
        catch /^command error \%x28/
        endtry
    endif
    if !empty($MANSECT)
        var MANSECT: string
        try
            MANSECT = $MANSECT
            unlet! $MANSECT
            return Get_path('', name)
        catch /^command error \%x28/
        finally
            $MANSECT = MANSECT
        endtry
    endif
    throw 'No manual entry for ' .. name
    return ''
enddef

def Get_path(sect: string, name: string): string #{{{3
# Some man  implementations (OpenBSD)  return all  available paths  from the
# search command, so we `get()` the first one. #8341

    # `-S` flag handles:{{{
    #
    #   - tokens like `printf(echo)`
    #   - sections starting with `-`
    #   - 3pcap section (found on macOS)
    #   - commas between sections (for section priority)
    #}}}
    return Job_start(empty(sect) ? ['man', '-w', name] : ['man', '-w', '-S', sect, name])
        ->split()
        ->get(0, '')
        ->substitute('\n\+$', '', '')
enddef

def Get_page(path: string): string #{{{3
    # Disable hard-wrap by using a big $MANWIDTH (max 1000 on some systems #9065).
    # Soft-wrap: ftplugin/man.vim sets wrap/breakindent/….
    # Hard-wrap: driven by `man`.
    var manwidth = !get(g:, 'man_hardwrap', true)
        ? 999
        : (empty($MANWIDTH) ? winwidth(0) : $MANWIDTH)
    # Force `MANPAGER=cat` to ensure Vim is not recursively invoked (by `man-db`).
    # http://comments.gmane.org/gmane.editors.vim.devel/29085
    # Set `MAN_KEEP_FORMATTING` so that Debian's `man(1)` doesn't discard backspaces.
    var cmd =<< trim END
        env
        MANPAGER=cat
        MANWIDTH=%d
        MAN_KEEP_FORMATTING=1
        man
    END
    cmd[2] = substitute(cmd[2], '%d', manwidth, '')
    return Job_start(cmd + (localfile_arg ? ['-l', path] : [path]))
enddef

def Put_page(page: string) #{{{3
    setl modifiable noreadonly noswapfile
    # `git-ls-files(1)` is all one keyword/tag-target
    setl iskeyword+=(,)
    :sil keepj %d _
    page->split('\n')->setline(1)
    while getline(1) =~ '^\s*$'
        :sil keepj 1d _
    endwhile
    # XXX: nroff justifies text by filling it with whitespace.  That interacts
    # badly with our use of `$MANWIDTH=999`.  Hack around this by using a fixed
    # size for those whitespace regions.
    :sil! keepp keepj %s/\s\{199,}/\=repeat(' ', 10)/g
    :1
    Highlight_on_cursormoved()
    OpenFolds()
    setl filetype=man
enddef

def Job_start(cmd: list<string>): string #{{{3
# Run a shell command asynchronously; timeout after 30 seconds.
    var opts = #{
        stdout: '',
        stderr: '',
        exit_status: 0,
        }

    var job = job_start(cmd, #{
        out_cb: function(Job_handler, [opts, 'stdout']),
        err_cb: function(Job_handler, [opts, 'stderr']),
        exit_cb: function(Job_handler, [opts, 'exit']),
        mode: 'raw',
        noblock: true,
        })

    if job_status(job) !=? 'run'
        # Tip: to get more info about the job which has started the process of ID 1234
        #     :echo job_info()->map({_, v -> job_info(v)})->filter({_, v -> v.process == 1234})
        printf('job error (PID %d): %s', job_info(job).process, join(cmd))
            ->Error()
    endif

    # let's wait up to 30 seconds
    var res = -1
    try
        var start = reltime()
        while reltime(start)->reltimefloat() < 30.0
            var info = job_info(job)
            if info.status == 'dead'
                res = info.exitval
                break
            elseif info.status == 'fail'
                res = -3
                break
            endif
            sleep 1m
        endwhile
    catch /^Vim:Interrupt$/
        res = -2
    endtry

    if res == -1
        try
            job_stop(job)
            printf('job timed out (PID %d): %s', job_info(job).process, join(cmd))
                ->Error()
        catch /^Vim(call):E900:/
        endtry
    elseif res == -2
        throw printf('job interrupted (PID %d): %s', job_info(job).process, join(cmd))
    endif
    # if you ask for an unknown man page, the job will exit with the status `16`
    if opts.exit_status != 0
        # Do *not* change anything in the text!{{{
        #
        # If you really want to, make sure that the new message is still matched
        # by the patterns used in the try/catch in `Verify_exists()`.
        #
        #     try
        #         ...
        #     catch /^command error \%x28/
        #            ^------------------^
        #     endtry
        #
        # Otherwise, when  you ask  for an  unknown man page,  you'll get  a too
        # noisy error message.
        # For example,  if you replace "command"  with "job", and you  run `:Man
        # unknown`, you'll get this error message:
        #
        #     man.vim: job error (PID 1826) man -w unknown: No manual entry for unknown
        #
        # Instead of the more readable:
        #
        #     man.vim: No manual entry for unknown
        #
        # Besides, `Verify_exists()` will return earlier than expected.
        # IOW, the function's logic is affected.
        #}}}
        throw printf('command error (PID %d) %s: %s',
                job_info(job).process,
                join(cmd),
                substitute(opts.stderr, '\_s\+$', '', ''))
    endif

    # FIXME: Sometimes, a man page is truncated when we use `:Man`.{{{
    #
    # A few characters are missing from a  line, and the next few lines are also
    # missing.  No issue with `$ man`.
    #
    # Does the issue also affect Neovim?
    # Where does it come from?
    # It's non-deterministic.  It doesn't happen all the time.
    # It happens  more frequently with  `ffmpeg-all(1)`, but it can  also affect
    # shorter man pages such as `tmux(1)` (maybe less frequently though).
    #
    # Update: The issue comes from the fact that we return too early.
    # I think that sometimes, even though the  job is dead, there might still be
    # some data on the channel.  How to flush that data?
    # Did we make a mistake when reducing the code from `vim-async`?
    # Or was there some bug in the latter?
    # If so, I suspect it's in `async#jobwait()`.
    #
    # As a temporary workaround, we sleep for 1 ms to give more time to the job.
    # But remember that this function is called several times; often just to get
    # the path to a man page.  We only need this extra sleep for when we ask the
    # job to give us the contents of our man page.
    #}}}
    # TODO: Why is this `Job_start()` function called so many times?{{{
    #
    # Value of `cmd` each time the function is called when we run `:Man ffmpeg-all`:
    #
    #     ['man', '-w', 'man']
    #     ['env', 'MANPAGER=cat', 'MANWIDTH=80', 'MAN_KEEP_FORMATTING=1', 'man', '-l', '/usr/share/man/man1/man.1']
    #     ['man', '-w', '-S', '1', 'ffmpeg-all']
    #     ['man', '-w']
    #     ['man', '-w', '-S', '1', 'ffmpeg-all']
    #     ['man', '-w', '/usr/share/man/man1/ffmpeg-all.1.gz']
    #     ['env', 'MANPAGER=cat', 'MANWIDTH=80', 'MAN_KEEP_FORMATTING=1', 'man', '-l', '/usr/share/man/man1/ffmpeg-all.1.gz']
    #
    # In particular, `man -w` seems useless...
    # Do we need `sleep 1` for the first `env ...`?
    #}}}
    if cmd[0] == 'env'
        sleep 1m
    endif
    return opts.stdout
enddef

def Job_handler(opts: dict<any>, event: string, _: any, data: any) #{{{3
# When the callback  is invoked to write  on the stdout or stderr,  `_` is a
# channel and `data` a string.
# When the  callback is  invoked because  the job  exits, `_`  is a  job and
# `data` a number (exit status).
    if event == 'stdout' || event == 'stderr'
        opts[event] = opts[event] .. data
    else
        extend(opts, #{exit_status: data})
    endif
enddef
#}}}2
# Highlighting {{{2
def Highlight_window() #{{{3
    if !exists('b:_seen')
        return
    endif
    var lnum1 = max([1, line('.') - winheight(0)])
    var lnum2 = min([line('.') + winheight(0), line('$')])
    # if the *visible* lines are already highlighted, nothing needs to be done
    # TODO: Once Vim9 supports `dict.key`, try to consolidate all `b:` variables
    # into a single dictionary.  And use the prefix `man`.
    if b:_seen[lnum1 - 1 : lnum2 - 1]->index(false) == -1
        # if *all* the lines are already highlighted, nothing will *ever* need to be done
        if index(b:_seen, false) == -1
            au! highlight_manpage
            aug! highlight_manpage
            unlet! b:_hls b:_lines b:_seen
        endif
        return
    endif

    var lines = b:_lines[lnum1 - 1 : lnum2 - 1]
    var i = 0
    var lnum: number
    for line in lines
        lnum = i + lnum1 - 1
        i += 1
        if b:_seen[lnum]
            continue
        endif
        Highlight_line(line, lnum)
        b:_seen[lnum] = true
    endfor

    for args in b:_hls
        prop_add(args[1] + 1, args[2] + 1, #{
            length: args[3] - args[2],
            type: args[0]
            })
    endfor
    b:_hls = []
enddef

def Highlight_line(line: string, linenr: number): string #{{{3
    var chars: list<string>
    var prev_char = ''
    var overstrike = false
    var escape = false
    var hls: list<dict<number>> # Store highlight groups as { attr, start, end }
    var NONE = 0
    var BOLD = 1
    var UNDERLINE = 2
    var ITALIC = 3
    var hl_groups = {
        string(BOLD): 'manBold',
        string(UNDERLINE): 'manUnderline',
        string(ITALIC): 'manItalic',
        }
    var attr = NONE
    var byte = 0 # byte offset

    def End_attr_hl(attr_: number)
        var i = 0
        for hl in hls
            if hl.attr == attr_ && hl.end == -1
                extend(hl, #{end: byte})
                hls[i] = hl
            endif
            i += 1
        endfor
    enddef

    def Add_attr_hl(code: number)
        var continue_hl = true
        if code == 0
            attr = NONE
            continue_hl = false
        elseif code == 1
            attr = BOLD
        elseif code == 22
            attr = BOLD
            continue_hl = false
        elseif code == 3
            attr = ITALIC
        elseif code == 23
            attr = ITALIC
            continue_hl = false
        elseif code == 4
            attr = UNDERLINE
        elseif code == 24
            attr = UNDERLINE
            continue_hl = false
        else
            attr = NONE
            return
        endif

        if continue_hl
            hls += [#{attr: attr, start: byte, end: -1}]
        else
            if attr == NONE
                for a_ in items(hl_groups)
                    End_attr_hl(a_[0])
                endfor
            else
                End_attr_hl(attr)
            endif
        endif
    enddef

    for char in Gmatch(line, '[^\d128-\d191][\d128-\d191]*')
        if overstrike
            var last_hl = get(hls, -1)
            if char == prev_char
                if char == '_' && attr == UNDERLINE
                    && !empty(last_hl)
                    && last_hl.end == byte
                    # This underscore is in the middle of an underlined word
                    attr = UNDERLINE
                else
                    attr = BOLD
                endif
            elseif prev_char == '_'
                # FIXME: In the `zshcontrib(1)` man page, look for "prompt_theme_setup".{{{
                #
                # Notice how `_theme_` is wrongly underlined.
                #
                # ---
                #
                # Move down a little until you find the "Writing Themes" SubHeading.
                # A lot of words are wrongly underlined after "prompt_name_setup".
                #
                # ---
                #
                # Same issue in Neovim.
                #
                # ---
                #
                # Look at the source:
                #
                #     /usr/local/share/man/man1/zshcontrib.1
                #
                # I think there are 2 issues.
                # First, in  "prompt_theme_setup", "theme" should  be underlined
                # (or italic?), *and* bold.  IOW, the current logic is unable to
                # combine attributes.  Same thing with "prompt_name_setup".
                #
                # Second, because  of the  first issue (I  guess...), everything
                # after "prompt_name_setup" is wrongly underlined.
                #}}}
                # char is underlined
                attr = UNDERLINE
            elseif prev_char == '+' && char == 'o'
                # bullet (overstrike text `+^Ho`)
                attr = BOLD
                char = '·'
            elseif prev_char == '·' && char == 'o'
                # bullet (additional handling for `+^H+^Ho^Ho`)
                attr = BOLD
                char = '·'
            else
                # use plain char
                attr = NONE
            endif

            # Grow the previous highlight group if possible
            if !empty(last_hl)
                && last_hl.attr == attr
                && last_hl.end == byte
                extend(last_hl, #{end: byte + strlen(char)})
            else
                hls += [#{attr: attr, start: byte, end: byte + strlen(char)}]
            endif

            overstrike = false
            prev_char = ''
            byte += strlen(char)
            chars += [char]
        elseif escape
            # Use prev_char to store the escape sequence
            prev_char ..= char
            # We only want to match against SGR sequences, which consist of ESC
            # followed by `[`, then a series of parameter and intermediate bytes in
            # the range 0x20 - 0x3f, then `m`. (See ECMA-48, sections 5.4 & 8.3.117)
            var sgr = matchstr(prev_char, '^\[\zs[\d032-\d063]*\zem$')
            # Ignore escape sequences with : characters, as specified by ITU's T.416
            # Open Document Architecture and interchange format.
            if sgr && stridx(sgr, ':') == -1
                var match: string
                while sgr && strlen(sgr) > 0
                    # Match against SGR parameters, which may be separated by `;`
                    var matchlist = matchlist(sgr, '^\(\d*\);\=\(.*\)')
                    match = matchlist[1]
                    sgr = matchlist[2]
                    str2nr(match)->Add_attr_hl()
                endwhile
                escape = false
            elseif match(prev_char, '^%[[\d032-\d063]*$') == -1
                # Stop looking if this isn't a partial CSI sequence
                escape = false
            endif
        elseif char == "\027"
            escape = true
            prev_char = ''
        elseif char == "\b"
            overstrike = true
            prev_char = chars[-1]
            byte -= strlen(prev_char)
            chars[-1] = ''
        else
            byte += strlen(char)
            chars += [char]
        endif
    endfor

    for hl in hls
        if hl.attr != NONE
            b:_hls += [[
                get(hl_groups, string(hl.attr), ''),
                linenr,
                hl.start,
                hl.end,
                ]]
        endif
    endfor

    return join(chars, '')
enddef

def Highlight_on_cursormoved() #{{{3
    b:_hls = []
    b:_lines = getline(1, '$')
    # Remove backspaces used to display bold or underlined text.{{{
    #
    # In  the past,  old  printers would  use  `_`  and `^H`  to  print bold  or
    # underlined text.  The `^H`  would cause the print head to  back up so that
    # the next  character would stamp over  the previous one.  So,  `X^HX` would
    # stamp `X` twice,  bolding it.  Similarly, `_^HX` would stamp  `X` over `_`
    # to underline the latter.
    #
    # There is a syntax script which can highlight such a text:
    #
    #     $ vim -Nu NONE -S <(cat <<'EOF'
    #         let lines = [
    #             \ "this w\bwo\bor\brd\bd is bold",
    #             \ "this _\bw_\bor\b_d\b_ is underlined"
    #             \ ]
    #         call setline(1, lines)
    #         so $VIMRUNTIME/syntax/ctrlh.vim
    #     EOF
    #     )
    #
    # Anyway, we  don't want  those sequences,  and we  don't need  them anymore
    # because  we've just  saved the  original  lines; those  still contain  the
    # escape  sequences, which  we  will  use to  determine  where  to put  text
    # properties.
    #}}}
    :sil keepj keepp %s/.\b//ge
    b:_seen = repeat([false], line('$'))
    augroup highlight_manpage
        au! * <buffer>
        au CursorMoved <buffer> Highlight_window()
        # for  when  we   type  a  pattern  on  the   search  command-line,  and
        # `'incsearch'` is set (causing the view to change)
        exe 'au CmdlineChanged /,\? '
            .. 'if bufnr("%") == ' .. bufnr('%')
            .. ' | Highlight_window() | endif'
    augroup END
enddef
#}}}2
# :Man completion {{{2
def Complete(sect: string, psect: string, name: string): list<string> #{{{3
    var pages = Get_paths(sect, name, false)
    # We remove duplicates in case the same manpage in different languages was found.
    return map(pages, {_, v -> Format_candidate(v, psect)})
        ->sort('i')
        ->uniq()
        # TODO: Instead of running  `filter()` just to remove  one empty string,{{{
        # refactor `Format_candidate()` so that it returns a number (`0`):
        #
        #     if path =~ '\.\%(pdf\|in\)$' # invalid extensions
        #         return ''
        #     endif
        #
        #     ...
        #
        #     return ''
        #
        #     →
        #
        #     if path =~ '\.\%(pdf\|in\)$' # invalid extensions
        #         return 0
        #     endif
        #
        #     ...
        #
        #     return 0
        #
        # For this to work, you'll need  to change the return type from `string`
        # to `any`.  Also, you'll need to report a crash, and wait for a fix.
        #}}}
        ->filter({_, v -> !empty(v)})
enddef

def Get_paths(sect: string, name: string, do_fallback: bool): list<string> #{{{3
# see `Extract_sect_and_name_ref()` on why `tolower(sect)`

    # callers must try-catch this, as some `man(1)` implementations don't support `-w`
    try
        var mandirs = Job_start(['man', '-w'])
            ->split(':\|\n')
            ->join(',')
        var paths = globpath(mandirs, 'man?/' .. name .. '*.' .. sect .. '*', false, true)
        try
            # Prioritize the result from verify_exists as it obeys b:man_default_sects.
            var first = Verify_exists(sect, name)
            filter(paths, {_, v -> v != first})
            paths = [first] + paths
        catch
        endtry
        return paths
    catch
        if !do_fallback
            throw v:exception
        endif

        # Fallback to a single path, with the page we're trying to find.
        try
            return [Verify_exists(sect, name)]
        catch
            return []
        endtry
    endtry
    return []
enddef

def Format_candidate(path: string, psect: string): string #{{{3
    if path =~ '\.\%(pdf\|in\)$' # invalid extensions
        return ''
    endif
    var sect: string
    var name: string
    [sect, name] = Extract_sect_and_name_path(path)
    if sect == psect
        return name
    elseif sect =~ psect .. '.\+$'
        # We include the section if the user provided section is a prefix
        # of the actual section.
        return name .. '(' .. sect .. ')'
    endif
    return ''
enddef
#}}}2
#}}}1
# Utitilities {{{1
def Error(msg: string) #{{{2
    redraw
    echohl ErrorMsg
    echom 'man.vim: ' .. msg
    echohl None
enddef

def Find_man(): bool #{{{2
    var win = 1
    while win <= winnr('$')
        var buf = winbufnr(win)
        if getbufvar(buf, '&filetype', '') == 'man'
            execute ':' .. win .. 'wincmd w'
            return true
        endif
        win += 1
    endwhile
    return false
enddef

def Gmatch(text: string, pat: string): list<string> #{{{2
# TODO: Is there something simpler?
# If not, consider asking for a builtin `gmatch()` as a feature request.
    var res: list<string>
    substitute(text, pat, {m -> add(res, m[0])[-1]}, 'g')
    return res
enddef

def OpenFolds() #{{{2
    # The autocmd is necessary in case we jump to another man page with `C-]`.
    # Also when we come back with `C-t`.
    augroup man_all_folds_open_by_default
        au! * <buffer>
        au BufWinEnter <buffer> setl foldlevel=1
    augroup END
enddef
#}}}1
# Init {{{1

try
    # check for `-l` support
    Get_path('', 'man')->Get_page()
catch /E145:/
    # ignore the error in restricted mode
catch /command error .*/
    localfile_arg = false
endtry

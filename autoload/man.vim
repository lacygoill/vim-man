vim9script noclear

var MAN_PAGES_TO_GREP: dict<list<string>>

var localfile_arg: bool = true  # Always use -l if possible. #6683

# TODO: `p` could be used to preview a  reference to another man page in a popup
# window. `]r` and `]o` could be used to jump to the next reference or option.

# TODO: Implement an ad-hoc annotations feature?
# They could be saved persistently in files, and displayed via popup windows.

# TODO: Implement `:Mangrep`:
# https://github.com/vim-utils/vim-man#about-mangrep

# Init {{{1

const NONE: number = 0
const BOLD: number = 1
const UNDERLINE: number = 2
const ITALIC: number = 3
const HL_GROUPS: dict<string> = {
    [BOLD]: 'manBold',
    [UNDERLINE]: 'manUnderline',
    [ITALIC]: 'manItalic',
}

# Interface {{{1
export def InitPager() # {{{2
    # Called when Vim is invoked as $MANPAGER.

    # clear message:  "-stdin-" 123L, 456B
    echo ''

    autocmd VimEnter * {
        cursor(1, 1)
        &l:foldlevel = 20
    }

    if getline(1) !~ '\S'
        bufnr('%')->deletebufline(1, 1)
    endif
    HighlightOnCursormoved()
    OpenFolds()

    # Copy the reference from the heading.
    #     BASH(1)                     General Commands Manual                    BASH(1)
    #     ^-----^
    var ref: string = getline(1)
        ->matchstr('^[^)]\+)')
        ->substitute(' ', '_', 'g')
    try
        b:man_sect = ref->ExtractSectAndNameFromRef()[0]
    catch
        b:man_sect = ''
    endtry
    # Need to return if `ref` is empty.{{{
    #
    # Which can happen like this:
    #
    #     $ man man
    #     :edit /tmp/file.man
    #
    # And if  `ref` is  empty, we  need to  return to  prevent Vim  from wrongly
    # creating an undesirable (and unmodifiable) buffer.  That is, after
    # `:edit /tmp/file.man`, we want this buffer list:
    #
    #     ✔
    #     1 #h-  "man://man(1)"                 line 1
    #     2 %a-  "/tmp/file.man"                line 1
    #
    # *Not* this one:
    #
    #     ✘
    #     1  h-  "man://man(1)"                 line 1
    #     2 %a-  "man://"                       line 1
    #     3u#    "/tmp/file.man"                line 1
    #
    # The latter is confusing, and creates other unexpected errors:
    #
    #     :edit %%
    #
    #     E95: Buffer with this name already exists˜
    #}}}
    # Do not move this check above the `b:man_sect` assignment.{{{
    #
    # It would give another error:
    #
    #     $ man man
    #     :edit /tmp/file.man
    #
    #     E121: Undefined variable: b:man_sect˜
    #}}}
    if ref->empty()
        return
    endif
    if bufname('%') !~ 'man:\/\/'  # Avoid duplicate buffers, E95.
        $'silent file man://{ref->fnameescape()->tolower()}'->execute()
    endif

    SetOptions()
enddef

export def ShellCmd(ref: string) # {{{2
    # Called when a man:// buffer is opened.
    var sect: string
    var name: string
    var page: string
    try
        [sect, name] = ExtractSectAndNameFromRef(ref)
        var path: string = VerifyExists(sect, name)
        [sect, name] = ExtractSectAndNameFromPath(path)
        page = GetPage(path)
    catch
        Error(v:exception)
        return
    endtry
    b:man_sect = sect
    PutPage(page)
enddef

export def ExCmd( # {{{2
        count: number,
        mods: string,
        ...fargs: list<string>
        )
    var ref: string
    if len(fargs) > 2
        Error('too many arguments')
        return
    elseif len(fargs) == 0
        ref = &filetype == 'man' ? expand('<cWORD>') : expand('<cword>')
        if ref->empty()
            Error('no identifier under cursor')
            return
        endif
    elseif len(fargs) == 1
        ref = fargs[0]
    else
        # Combine  the name  and sect  into  a man  page reference  so that  all
        # verification/extraction can be kept in a single function.
        # If `farg[1]` is  a reference as well,  that is fine because  it is the
        # only reference that will match.
        ref = $'{fargs[1]}({fargs[0]})'
    endif
    var sect: string
    var name: string
    try
        [sect, name] = ExtractSectAndNameFromRef(ref)
        if count > 0
            sect = string(count)
        endif
        var path: string = VerifyExists(sect, name)
        [sect, name] = ExtractSectAndNameFromPath(path)
    catch
        Error(v:exception)
        return
    endtry

    var buf: number = bufnr('%')
    var tagfunc_save: string = &l:tagfunc
    try
        &l:tagfunc = 'GoToTag'
        var target: string = $'{name}({sect})'
        if mods !~ 'tab' && FindMan()
            $'silent keepalt tag {target}'->execute()
        else
            $'silent keepalt {mods} stag {target}'->execute()
        endif
        SetOptions()
    # E987: invalid return value from tagfunc
    # *given when you ask for an unknown man page*
    catch /E987:/
        Error(v:exception)
        return
    finally
        setbufvar(buf, '&tagfunc', tagfunc_save)
    endtry

    b:man_sect = sect
enddef

export def CmdComplete( # {{{2
        arg_lead: string,
        cmdline: string,
        _
        ): list<string>

    var args: list<string> = cmdline->split()
    var cmd_offset: number = args->index('Man')
    if cmd_offset > 0
        # Prune all arguments up to :Man itself. Otherwise modifier commands like
        # :tab, :vertical, etc. would lead to a wrong length.
        args = args[cmd_offset :]
    endif
    var l: number = len(args)
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
        var tmp: list<string> = arg_lead->split('(')
        name = tmp[0]
        return tmp
            ->get(1, '')
            ->tolower()
            ->Complete('', name)
    elseif args[1] !~ '^[^()]\+$'
        # cursor (|) is at `:Man 3() |` or `:Man (3|` or `:Man 3() pri|`
        # or `:Man 3() pri |`
        return []
    elseif l == 2
        if arg_lead->empty()
            # cursor (|) is at `:Man 1 |`
            name = ''
            sect = tolower(args[1])
        else
            # cursor (|) is at `:Man pri|`
            if arg_lead =~ '\/'
                # if the name is a path, complete files
                # TODO(nhooyr) why does this complete the last one automatically
                return glob($'{arg_lead}*', false, true)
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

export def GoToTag(pattern: string, _, _): list<dict<string>> # {{{2
    var sect: string
    var name: string
    [sect, name] = ExtractSectAndNameFromRef(pattern)

    var paths: list<string> = GetPaths(sect, name, true)
    var structured: list<dict<string>>

    for path: string in paths
        [sect, name] = ExtractSectAndNameFromPath(path)
        structured->add({
            name: name,
            title: $'{name}({sect})'
        })
    endfor

    if &cscopetag
        # return only a single entry so we work well with :cstag (#11675)
        structured = structured[: 0]
    endif

    return structured
        ->map((_, entry: dict<string>) => ({
            name: entry.name,
            filename: $'man://{entry.title}',
            cmd: 'keepjumps normal! 1G'
        }))
enddef

export def FoldExpr(): string # {{{2
    if indent(v:lnum) == 0 && getline(v:lnum) =~ '\S'
            || indent(v:lnum) == 3
        return '>1'
    endif
    return '1'
enddef

export def FoldTitle(): string # {{{2
    var title: string = getline(v:foldstart)
    var indent: string = title->matchstr('^\s*')
    if get(b:, 'foldtitle_full', false)
        var foldsize: number = v:foldend - v:foldstart
        var linecount: string = $'[{foldsize}]{repeat(' ', 4 - len(foldsize))}'
        return $'{indent}{foldsize > 1 ? linecount : ''}{title}'
    else
        return $'{indent}{title}'
    endif
enddef

export def JumpToRef(is_fwd = true) # {{{2
    # regex used by the `manReference` syntax group
    var pat: string = '[^()[:space:]]\+([0-9nx][a-z]*)'
    var flags: string = is_fwd ? 'W' : 'bW'
    search(pat, flags)
enddef

export def Grep(args: string) # {{{2
    if args == '' || args =~ '^\%(--help\|-h\)\>'
        var help: list<string> =<< trim END
            # look for pattern "foo" in all man pages using current filetype as topic
            :ManGrep foo
            # look for pattern "foo" in all man pages using "bar" as topic
            :ManGrep --apropos=bar foo
        END
        for line: string in help
            var hg: string = line =~ '^:' ? 'Statement' : 'Comment'
            $'echohl {hg}'->execute()
            echo line
            echohl NONE
        endfor
        return
    endif

    var topic: string = args->matchstr('^--apropos=\zs\S*') ?? &filetype
    var pattern: string = args->substitute('^--apropos=\S*\s*', '', '')
    if topic == ''
        echo 'missing topic'
        return
    elseif pattern == ''
        echo 'missing pattern'
        return
    endif

    if !MAN_PAGES_TO_GREP->has_key(topic)
        if topic == 'fish'
            silent var fish_mandir: string = system("fish -c 'echo $__fish_data_dir'")
                ->trim() .. '/man/man1'
            MAN_PAGES_TO_GREP.fish = fish_mandir
                ->readdir()
                ->map((_, v: string) => $'man://{v}(1)')
                ->filter((_, v: string): bool => v !~ '\<fish-\%(doc\|releasenotes\)\>')

        # For  every config  file at  the root  of `/etc/systemd/`,  there exists  a
        # dedicated man page.   We don't need to grep *all*  systemd man pages; just
        # this one.
        elseif topic == 'systemd' && expand('%:p') =~ '^/etc/systemd/.*\.conf$'
            topic = $'systemd-{expand('%:p:t')}'
            silent system($'man --where {topic}')
            # These man pages follow an inconsistent naming scheme:{{{
            #
            #     # sometimes, they're prefixed with `systemd-`
            #     /etc/systemd/system.conf   → systemd-system.conf
            #     /etc/systemd/sleep.conf    → systemd-sleep.conf
            #
            #     # sometimes not
            #     /etc/systemd/journald.conf → journald.conf
            #     /etc/systemd/logind.conf   → logind.conf
            #
            # I guess  the `systemd-` prefix  is only used  when necessary to  avoid a
            # clash with another man page.
            #}}}
            if v:shell_error != 0
                topic = topic->substitute('systemd-', '', '')
            endif
            MAN_PAGES_TO_GREP[topic] = [$'man://{topic}']

        else
            silent var lines: list<string> = systemlist($'man --apropos {topic}')
            if v:shell_error != 0
                echo lines->join("\n")
                return
            endif
            # Why `300`?{{{
            #
            #     # for the "systemd" topic
            #     $ man --apropos systemd | wc --lines
            #     203
            #     ^^^
            #
            # Let's round that number to the nearest multiple of a hundred.
            #}}}
            if lines->len() > 300
                echo $'too many man pages match the topic: {topic}'
                return
            endif
            MAN_PAGES_TO_GREP[topic] = lines
                ->map((_, line: string) => line
                ->matchstr('[^(]*([^)]*)')
                ->substitute(' ', '', '')
                ->substitute('^', 'man://', ''))
        endif
    endif
    if MAN_PAGES_TO_GREP[topic]->empty()
        return
    endif

    try
        $'vimgrep /{pattern}/gj {MAN_PAGES_TO_GREP[topic]->join()}'->execute()

        # Problem: the qf list gets broken once we start jumping to its entries.{{{
        #
        # Initially, the man buffers are unloaded.
        # Vim  loads a  man  buffer as  soon  as  you start  jumping  to one  of
        # its  quickfix  entry.   And  when  that  happens,  the  quickfix  list
        # automatically gets updated in a wrong way:
        #
        #     # before
        #     lnum: 123
        #     end_lnum: 123
        #
        #     # after
        #     lnum: <some big number beyond last lnum>
        #     end_lnum: 123
        #}}}
        # Solution: Save the qf list.  Load all the man buffers.  Restore the original qf list.

        # save qf list
        var title: string = getqflist({title: 0}).title
        var qflist: list<dict<any>> = getqflist()
        # load man buffers
        for man_page: string in MAN_PAGES_TO_GREP[topic]
            if bufexists(man_page)
                man_page->bufload()
            endif
        endfor
        # restore qf list
        setqflist(qflist, 'r')
        setqflist([], 'a', {title: title})

    # E480: No match: ...
    catch /^Vim\%((\a\+)\)\=:E480:/
        echohl ErrorMsg
        echomsg v:exception
        echohl NONE
    endtry
enddef

export def GrepComplete(..._): string # {{{2
    return ['-h', '--help', '--apropos=']->join("\n")
enddef
#}}}1
# Core {{{1
# Main {{{2
def ExtractSectAndNameFromRef(arg_ref: string): list<string> # {{{3
    # attempt to extract the name and sect out of `name(sect)`
    # otherwise just return the largest string of valid characters in ref

    if arg_ref[0] == '-'  # try `:Man -pandoc` with this disabled
        throw 'man page name cannot start with ''-'''
    endif
    var ref: string = arg_ref->matchstr('[^()]\+([^()]\+)')
    if ref->empty()
        var name: string = arg_ref->matchstr('[^()]\+')
        if name->empty()
            throw 'man page reference cannot contain only parentheses'
        endif
        return ['', SpacesToUnderscores(name)]
    endif
    var left: list<string> = ref->split('(')
    # see `:Man 3X curses` on why `tolower()`.
    # TODO(nhooyr) Not sure if this is portable across OSs
    # but I have not seen a single uppercase section.
    return [left[1]->split(')')[0]->tolower(), left[0]->SpacesToUnderscores()]
enddef

def ExtractSectAndNameFromPath(path: string): list<string> # {{{3
    # Extracts the name/section from the `path/name.sect`, because sometimes the actual section is
    # more specific than what we provided to `man` (try `:Man 3 App::CLI`).
    # Also on linux, name seems to be case-insensitive. So for `:Man PRIntf`, we
    # still want the name of the buffer to be `printf`.

    var tail: string = path->fnamemodify(':t')
    if path =~ '\.\%([glx]z\|bz2\|lzma\|Z\)$'  # valid extensions
        tail = tail->fnamemodify(':r')
    endif
    var sect: string = tail->matchstr('\.\zs[^.]\+$')
    var name: string = tail->matchstr('^.\+\ze\.')
    return [sect, name]
enddef

def VerifyExists(sect: string, name: string): string # {{{3
    # VerifyExists attempts to find the path to a man page
    # based on the passed section and name.
    #
    # 1. If the passed section is empty, b:man_default_sects is used.
    # 2. If the man page could not be found with the given sect and name,
    #    then another attempt is made with b:man_default_sects.
    # 3. If it still could not be found, then we try again without a section.
    # 4. If still not found but $MANSECT is set, then we try again with $MANSECT
    #    unset.
    #
    # This function is careful to avoid duplicating a search if a previous
    # step has already done it. i.e if we use b:man_default_sects in step 1,
    # then we don't do it again in step 2.
    if sect->empty()
        # no section specified, so search with b:man_default_sects
        if exists('b:man_default_sects')
            var sects: list<string> = b:man_default_sects->split(',')
            for sec: string in sects
                try
                    var res: string = GetPath(sec, name)
                    if !res->empty()
                        return res
                    endif
                catch /^command error (/
                endtry
            endfor
        endif
    else
        # try with specified section
        try
            var res: string = GetPath(sect, name)
            if !res->empty()
                return res
            endif
        catch /^command error (/
        endtry
        # try again with b:man_default_sects
        if exists('b:man_default_sects')
            var sects: list<string> = b:man_default_sects->split(',')
            for sec: string in sects
                try
                    var res: string = GetPath(sec, name)
                    if !res->empty()
                        return res
                    endif
                catch /^command error (/
                endtry
            endfor
        endif
    endif

    # if none of the above worked, we will try with no section
    try
        var res: string = GetPath('', name)
        if !res->empty()
            return res
        endif
    catch /^command error (/
    endtry

    # if that still didn't work, we will check for $MANSECT and try again with it
    # unset
    if $MANSECT != ''
        var MANSECT: string
        try
            MANSECT = $MANSECT
            setenv('MANSECT', null)
            var res: string = GetPath('', name)
            if !res->empty()
                return res
            endif
        catch /^command error (/
        finally
            setenv('MANSECT', MANSECT)
        endtry
    endif

    # finally, if that didn't work, there is no hope
    throw $'No manual entry for {name}'
enddef

def GetPath(sect: string, name: string): string # {{{3
    # Some man  implementations (OpenBSD)  return all  available paths  from the
    # search command. Previously, this function would simply select the first one.
    #
    # However, some searches  will report matches that are incorrect:  man -w strlen
    # may return  string.3 followed by  strlen.3, and therefore selecting  the first
    # would get us the wrong page.  Thus, we must find the first matching one.
    #
    # There's yet  another special case here.   Consider the following:  If  you run
    # man -w  strlen and  string.3 comes  up first,  this is  a problem.   We should
    # search for a matching  named one in the results list.   However, if you search
    # for man  -w clock_gettime, you  will *only*  get clock_getres.2, which  is the
    # right page.  Searching  the resuls for clock_gettime will no  longer work.  In
    # this case,  we should just  use the  first one that  was found in  the correct
    # section.
    #
    # Finally,  we  can  avoid  relying  on  -S or  -s  here  since  they  are  very
    # inconsistently supported.  Instead, call -w with a section and a name.

    var results: list<string> = (sect == '' ? ['man', '--where', name] : ['man', '--where', sect, name])
        ->Job_start()
        ->split()
    if results->empty()
        return ''
    endif

    # find any that match the specified name
    var namematches: list<string> = results
        ->copy()
        ->filter((_, v: string): bool => v->fnamemodify(':t') =~ name)
    var sectmatches: list<string>

    if !namematches->empty() && !sect->empty()
        sectmatches = namematches
            ->copy()
            ->filter((_, v: string): bool => fnamemodify(v, ':e') == sect)
    endif

    return sectmatches
        ->get(0, namematches->get(0, results[0]))
        ->substitute('\n\+$', '', '')
enddef

def GetPage(path: string): string # {{{3
    # Disable hard-wrap by using a big $MANWIDTH (max 1000 on some systems #9065).
    # Soft-wrap: ftplugin/man.vim sets wrap/breakindent/….
    # Hard-wrap: driven by `man`.
    var manwidth: number = !get(g:, 'man_hardwrap', true)
        ? 999
        : ($MANWIDTH == '' ? winwidth(0) : $MANWIDTH->str2nr())
    # Force `MANPAGER=cat` to ensure Vim is not recursively invoked (by `man-db`).
    # http://comments.gmane.org/gmane.editors.vim.devel/29085
    # Set `MAN_KEEP_FORMATTING` so that Debian's `man(1)` doesn't discard backspaces.
    var cmd: list<string> =<< trim eval END
        env
        MANPAGER=cat
        MANWIDTH={manwidth}
        MAN_KEEP_FORMATTING=1
        man
    END
    return Job_start(cmd + (localfile_arg ? ['-l', path] : [path]))
enddef

def PutPage(page: string) # {{{3
    &l:modifiable = true
    &l:readonly = false
    &l:swapfile = false
    silent keepjumps :% delete _
    page->split('\n')->setline(1)
    while getline(1) !~ '\S'
        silent keepjumps :1 delete _
    endwhile
    # XXX: nroff justifies text by filling it with whitespace.  That interacts
    # badly with our use of `$MANWIDTH=999`.  Hack around this by using a fixed
    # size for those whitespace regions.
    silent keeppatterns keepjumps lockmarks :% substitute/\s\{199,}/\=repeat(' ', 10)/ge
    :1
    HighlightOnCursormoved()
    OpenFolds()
    SetOptions()
enddef

def Job_start(cmd: list<string>): string # {{{3
    # Run a shell command asynchronously; timeout after 30 seconds.
    var cb_opts: dict<any> = {
        stdout: '',
        stderr: '',
        exit_status: 0,
    }

    var job: job = cmd
        ->filter((_, v: string): bool => v != '')
        ->job_start({
            out_cb: function(JobHandler, [cb_opts, 'stdout']),
            err_cb: function(JobHandler, [cb_opts, 'stderr']),
            # TODO: Should we use `close_cb` instead?
            # https://vi.stackexchange.com/questions/27963/why-would-job-starts-close-cb-sometimes-not-be-called
            exit_cb: function(JobHandler, [cb_opts, 'exit']),
            in_io: 'null',
            mode: 'raw',
            noblock: true,
        })

    if job_status(job) !=? 'run'
        printf('job error (PID %d): %s', job_info(job).process, join(cmd))
            ->Error()
        return ''
    endif

    # let's wait up to 30 seconds
    var res: number = -1
    try
        var start: list<number> = reltime()
        while reltime(start)->reltimefloat() < 30.0
            var info: dict<any> = job_info(job)
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
            return ''
        catch /^Vim(call):E900:/
        endtry
    elseif res == -2
        throw printf('job interrupted (PID %d): %s', job_info(job).process, join(cmd))
    endif
    # if you ask for an unknown man page, the job will exit with the status `16`
    if cb_opts.exit_status != 0
        # Do *not* change anything in the text!{{{
        #
        # If you really want to, make sure that the new message is still matched
        # by the patterns used in the try/catch in `VerifyExists()`.
        #
        #     try
        #         ...
        #     catch /^command error (/
        #            ^--------------^
        #     endtry
        #
        # Otherwise, when  you ask  for an  unknown man page,  you'll get  a too
        # noisy error message.
        # For example,  if you replace `command`  with `job`, and you  run `:Man
        # unknown`, you'll get this error message:
        #
        #     man.vim: job error (PID 1826) man -w unknown: No manual entry for unknown
        #
        # Instead of the more readable:
        #
        #     man.vim: No manual entry for unknown
        #
        # Besides, `VerifyExists()` will return earlier than expected.
        # IOW, the function's logic is affected.
        #}}}
        throw printf('command error (PID %d) %s: %s',
            job_info(job).process,
            join(cmd),
            cb_opts.stderr->substitute('\_s\+$', '', ''))
    endif

    # FIXME: Sometimes, a man page is truncated when we use `:Man`.{{{
    #
    #     $ vim +'Man ffmpeg-all | normal! G'
    #
    # A few characters are missing from a  line, and the next few lines are also
    # missing.  No issue with `$ man`.
    #
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
    return cb_opts.stdout
enddef

def JobHandler( # {{{3
        opts: dict<any>,
        event: string,
        _,
        data: any
        )
    # When the callback  is invoked to write  on the stdout or stderr,  `_` is a
    # channel and `data` a string.
    # When the  callback is  invoked because  the job  exits, `_`  is a  job and
    # `data` a number (exit status).
    if event == 'stdout' || event == 'stderr'
        opts[event] ..= data
    else
        opts.exit_status = data
    endif
enddef

def SetOptions() # {{{3
    &l:bufhidden = 'hide'
    &l:buftype = 'nofile'
    &l:filetype = 'man'
    &l:modifiable = false
    &l:modified = false
    &l:readonly = true
    &l:swapfile = false
enddef
#}}}2
# Highlighting {{{2
def HighlightWindow() # {{{3
    if !exists('b:man_highlight')
            || !b:man_highlight->has_key('seen')
            # To avoid `E971` if syntax highlighting is not enabled:
            #     E971: Property type manBold does not exist
            || !has('syntax_items')
        return
    endif

    var lnum1: number = [1, line('.') - winheight(0)]->max()
    var lnum2: number = [line('.') + winheight(0), line('$')]->min()
    # if the *visible* lines are already highlighted, nothing needs to be done
    if b:man_highlight.seen[lnum1 - 1 : lnum2 - 1]->index(false) == -1
        # if *all* the lines are already highlighted, nothing will *ever* need to be done
        if b:man_highlight.seen->index(false) == -1
            autocmd! HighlightManPage
            augroup! HighlightManPage
            unlet! b:man_highlight
        endif
        return
    endif

    var lines: list<string> = b:man_highlight.lines[lnum1 - 1 : lnum2 - 1]
    var lnum: number
    for [i: number, line: string] in lines->items()
        lnum = i + lnum1 - 1
        if b:man_highlight.seen[lnum]
            continue
        endif
        HighlightLine(line, lnum)
        b:man_highlight.seen[lnum] = true
    endfor

    # TODO: Investigate  whether  `prop_add_list()`  could let  us  install  all
    # the  properties in  a  single  step (instead  of  splitting  them on  each
    # `CursorMoved`), without getting worse performance.
    for textprop: list<any> in b:man_highlight.textprops
        prop_add(textprop[1] + 1, textprop[2] + 1, {
            length: textprop[3] - textprop[2],
            type: textprop[0]
        })
    endfor
    b:man_highlight.textprops = []
enddef

def HighlightLine(line: string, linenr: number) # {{{3
    var chars: list<string>
    var prev_char: string = ''
    var overstrike: bool = false
    var escape: bool = false
    var highlights: list<dict<number>>  # Store highlight groups as { attr, start, end }
    var attr: number = NONE
    var byte: number = 0  # byte offset

    def EndAttrHl(attr_: number)
        for [i: number, highlight: dict<number>] in highlights->items()
            if highlight.attr == attr_ && highlight.end == -1
                highlight.end = byte
                highlights[i] = highlight
            endif
        endfor
    enddef

    def AddAttrHl(code: number)
        var continue_hl: bool = true
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
            highlights->add({attr: attr, start: byte, end: -1})
        else
            if attr == NONE
                for a_: list<any> in items(HL_GROUPS)
                    EndAttrHl(a_[0])
                endfor
            else
                EndAttrHl(attr)
            endif
        endif
    enddef

    # TODO: Why did the plugin passed `line` to `Gmatch()`?{{{
    #
    #     line->Gmatch('[^\d128-\d191][\d128-\d191]*')
    #         ^--------------------------------------^
    #
    # Before  restoring   this  function  call,   be  aware  that   it  breaks
    # `man apt-listchanges` when you jump on line 249:
    #
    #     E964: Invalid column number: 49
    #
    # That's because the line 249 unexpectedly contains 2 no-break spaces:
    #
    #     Example 1. Example configuration file
    #            ^  ^
    #
    # Which sometimes causes `char` to be  actually 2 characters, if `line` is
    # passed to `Gmatch()`, because  `[\d128-\d191]*` matches a no-break space
    # (but not a regular space).
    #}}}
    for char: string in line
        # Need to make a copy of `char`, because Vim automatically locks it, and
        # we might need to replace it during the loop (`c = '·'`).
        var c: string = char
        if overstrike
            var last_hl: dict<number> = get(highlights, -1, {})
            if c == prev_char
                if c == '_' && attr == UNDERLINE
                        && !last_hl->empty()
                        && last_hl.end == byte
                    # This underscore is in the middle of an underlined word
                    attr = UNDERLINE
                else
                    attr = BOLD
                endif
            elseif prev_char == '_'
                # FIXME: In the `zshcontrib(1)` man page, look for “prompt_theme_setup”.{{{
                #
                # Notice how `_theme_` is wrongly underlined.
                #
                # ---
                #
                # Move down a little until you find the “Writing Themes” SubHeading.
                # A lot of words are wrongly underlined after “prompt_name_setup”.
                #
                # ---
                #
                # Look at the source:
                #
                #     /usr/local/share/man/man1/zshcontrib.1
                #
                # I think there are 2 issues.
                # First, in  “prompt_theme_setup”, “theme” should  be underlined
                # (or italic?), *and* bold.  IOW, the current logic is unable to
                # combine attributes.  Same thing with “prompt_name_setup”.
                #
                # Second, because  of the  first issue (I  guess...), everything
                # after “prompt_name_setup” is wrongly underlined.
                #}}}
                # char is underlined
                attr = UNDERLINE
            elseif prev_char == '+' && c == 'o'
                # bullet (overstrike text `+^Ho`)
                attr = BOLD
                c = '·'
            elseif prev_char == '·' && c == 'o'
                # bullet (additional handling for `+^H+^Ho^Ho`)
                attr = BOLD
                c = '·'
            else
                # use plain char
                attr = NONE
            endif

            # Grow the previous highlight group if possible
            if !last_hl->empty()
                    && last_hl.attr == attr
                    && last_hl.end == byte
                last_hl.end = byte + strlen(c)
            else
                highlights->add({attr: attr, start: byte, end: byte + strlen(c)})
            endif

            overstrike = false
            prev_char = ''
            byte += strlen(c)
            chars->add(c)
        elseif escape
            # Use prev_char to store the escape sequence
            prev_char ..= c
            # We only want to match against SGR sequences, which consist of ESC
            # followed by `[`, then a series of parameter and intermediate bytes in
            # the range 0x20 - 0x3f, then `m`. (See ECMA-48, sections 5.4 & 8.3.117)
            var sgr: string = prev_char->matchstr('^\[\zs[\d032-\d063]*\zem$')
            # Ignore escape sequences with : characters, as specified by ITU's T.416
            # Open Document Architecture and interchange format.
            if !sgr->empty() && sgr->stridx(':') == -1
                var match: string
                while !sgr->empty() && sgr->strlen() > 0
                    # Match against SGR parameters, which may be separated by `;`
                    var matchlist: list<string> = matchlist(sgr, '^\(\d*\);\=\(.*\)')
                    match = matchlist[1]
                    sgr = matchlist[2]
                    str2nr(match)->AddAttrHl()
                endwhile
                escape = false
            elseif match(prev_char, '^%[[\d032-\d063]*$') == -1
                # Stop looking if this isn't a partial CSI sequence
                escape = false
            endif
        elseif c == "\027"
            escape = true
            prev_char = ''
        elseif c == "\<C-H>"
            overstrike = true
            prev_char = chars[-1]
            byte -= strlen(prev_char)
            chars[-1] = ''
        else
            byte += strlen(c)
            chars->add(c)
        endif
    endfor

    for highlight: dict<number> in highlights
        if highlight.attr != NONE
            b:man_highlight.textprops->add([
                get(HL_GROUPS, string(highlight.attr), ''),
                linenr,
                highlight.start,
                highlight.end,
            ])
        endif
    endfor
enddef

def HighlightOnCursormoved() # {{{3
    b:man_highlight = {}
    b:man_highlight.textprops = []
    b:man_highlight.lines = getline(1, '$')
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
    #     $ vim -Nu NONE -S <(tee <<'EOF'
    #         let lines = [
    #             \ "this w\<C-H>wo\<C-H>or\<C-H>rd\<C-H>d is bold",
    #             \ "this _\<C-H>w_\<C-H>or\<C-H>_d\<C-H>_ is underlined"
    #             \ ]
    #         call setline(1, lines)
    #         source $VIMRUNTIME/syntax/ctrlh.vim
    #     EOF
    #     )
    #
    # Anyway, we  don't want  those sequences,  and we  don't need  them anymore
    # because  we've just  saved the  original  lines; those  still contain  the
    # escape  sequences, which  we  will  use to  determine  where  to put  text
    # properties.
    #}}}
    silent keepjumps keeppatterns lockmarks :% substitute/.\b//ge
    b:man_highlight.seen = repeat([false], line('$'))
    augroup HighlightManPage
        autocmd! * <buffer>
        autocmd CursorMoved <buffer> HighlightWindow()
        # for  when  we   type  a  pattern  on  the   search  command-line,  and
        # `'incsearch'` is set (causing the view to change)
        autocmd! CmdlineChanged /,\? {
            if &filetype == 'man'
                HighlightWindow()
            endif
        }
        autocmd BufWipeout <buffer> autocmd SafeState * ++once HighlightTearDown()
    augroup END
enddef

def HighlightTearDown() # {{{3
    if !exists('#HighlightManpage')
        return
    endif
    if range(1, bufnr('$'))
            ->map((_, n: number): string => n->getbufvar('&filetype'))
            ->index('man') == -1
        autocmd! HighlightManPage
        augroup! HighlightManPage
    endif
enddef
#}}}2
# :Man completion {{{2
def Complete( # {{{3
        sect: string,
        psect: string,
        name: string
        ): list<string>

    var pages: list<string> = GetPaths(sect, name, false)
    # We remove duplicates in case the same man page in different languages was found.
    pages = pages
        ->map((_, v: string) => FormatCandidate(v, psect))
        ->sort('i')
        ->uniq()
    # happens when pressing Tab after `:Man 2 `
    if !pages->empty() && pages[0] == ''
        pages->remove(0)
    endif
    return pages
enddef

def GetPaths( # {{{3
        sect: string,
        name: string,
        do_fallback: bool
        ): list<string>
    # see `ExtractSectAndNameFromRef()` on why `tolower(sect)`

    # callers must try-catch this, as some `man(1)` implementations don't support `-w`
    try
        var mandirs: string = Job_start(['man', '--where'])
            ->split(':\|\n')
            ->join(',')
        var paths: list<string> = globpath(mandirs,
            $'man?/{name}*.{sect}*', false, true)
        try
            # Prioritize the result from verify_exists as it obeys b:man_default_sects.
            var first: string = VerifyExists(sect, name)
            paths->filter((_, v: string): bool => v != first)
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
            return [VerifyExists(sect, name)]
        catch
            return []
        endtry
    endtry
enddef

def FormatCandidate(path: string, psect: string): string # {{{3
    if path =~ '\.\%(pdf\|in\)$'  # invalid extensions
        return ''
    endif
    var sect: string
    var name: string
    [sect, name] = ExtractSectAndNameFromPath(path)
    if sect == psect
        return name
    elseif sect =~ $'{psect}.\+$'
        # We include the section if the user provided section is a prefix
        # of the actual section.
        return $'{name}({sect})'
    endif
    return ''
enddef
#}}}2
#}}}1
# Utitilities {{{1
def Error(msg: string) # {{{2
    redraw
    echohl ErrorMsg
    echomsg $'man.vim: {msg}'
    echohl None
enddef

def FindMan(): bool # {{{2
    for win: number in range(1, winnr('$'))
        var buf: number = winbufnr(win)
        if getbufvar(buf, '&filetype', '') == 'man'
            win_getid(win)->win_gotoid()
            return true
        endif
    endfor
    return false
enddef

def Gmatch(text: string, pat: string): list<string> # {{{2
    # TODO: Is there something simpler?
    # If not, consider asking for a builtin `gmatch()` as a feature request.
    var res: list<string>
    text->substitute(pat, (m: list<string>) => res->add(m[0])[-1], 'g')
    return res
enddef

def OpenFolds() # {{{2
    # The autocmd is necessary in case we jump to another man page with `C-]`.
    # Also when we come back with `C-t`.
    augroup ManAllFoldsOpenByDefault
        autocmd! * <buffer>
        autocmd BufWinEnter <buffer> &l:foldlevel = 1
    augroup END
enddef

def SpacesToUnderscores(str: string): string # {{{2
    # replace spaces in a man page name with underscores
    # intended for PostgreSQL, which has man pages like 'CREATE_TABLE(7)';
    # while editing SQL source code, it's nice to visually select 'CREATE TABLE'
    # and hit 'K', which requires this transformation
    return substitute(str, ' ', '_', 'g')
enddef
#}}}1
# Init {{{1

try
    # check for `-l` support
    GetPath('', 'man')->GetPage()
catch /command error .*/
    localfile_arg = false
endtry

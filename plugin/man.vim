vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

import autoload '../autoload/man.vim'

# `:Man foo` doesn't work!{{{
#
#     :Man foo
#     man.vim: Vim(stag):E987: invalid return value from tagfunc˜
#
# Check whether `$ man -w` can find the man page:
#
#     $ man -w foo
#
# If the output is empty, try to reinstall the program `foo`; or at least its man page.
#
# ---
#
# We had this issue  once with `tig(1)`, because the man  page was not correctly
# installed in `~/share/man`:
#
#     $ cd ~/share/man
#     $ tree
#     .˜
#     ├── cat1˜
#     │   ├── tig.1.gz˜
#     │   └── youtube-dl.1.gz˜
#     ├── index.db˜
#     └── man1˜
#         └── youtube-dl.1˜
#}}}

augroup man
    autocmd!
    autocmd BufReadCmd man://* {
        expand('<amatch>')
            ->substitute('^man://', '', '')
            ->man.ShellCmd()
    }
augroup END

# `-range=-1` will let us detect wheter `:Man` was given a count.
# If we don't give a count, `<count>` will be replaced with `-1`.
command -bang -bar -range=-1 -complete=customlist,man.CmdComplete -nargs=* Man {
    if <bang>0
        man.InitPager()
    else
        man.ExCmd(<count>, <q-mods>, <f-args>)
    endif
}
cnoreabbrev <expr> man getcmdtype() =~ '[:>]' && getcmdpos() == 4 ? 'Man' : 'man'

command -nargs=? -complete=custom,man.GrepComplete ManGrep man.Grep(<q-args>)
cnoreabbrev <expr> mg getcmdtype() =~ '[:>]' && getcmdpos() == 3 ? 'ManGrep' : 'mg'
augroup ManGrep
    autocmd!
    autocmd FileType fish {
        cnoreabbrev <expr> mg getcmdtype() =~ '[:>]' && getcmdpos() == 3 ? 'ManGrep --apropos=fish' : 'mg'
    }
augroup END

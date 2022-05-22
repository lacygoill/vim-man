vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

import autoload '../autoload/man.vim'

# `:Man foo` doesn't work!{{{
#
#     :Man foo
#     man.vim: Vim(stag):E987: invalid return value from tagfunc˜
#
# Check whether `$ man -w` can find the manpage:
#
#     $ man -w foo
#
# If the output is empty, try to reinstall the program `foo`; or at least its manpage.
#
# ---
#
# We had  this issue once with  `tig(1)`, because the manpage  was not correctly
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

# For `-range=-1`, see:
# https://github.com/tpope/vim-scriptease/commit/d15112a77d0aa278f8ca88f07d53b018be79b585
command -bang -bar -range=-1 -complete=customlist,man.CmdComplete -nargs=* Man {
    if <bang>0
        man.InitPager()
    else
        man.ExCmd(<count>, <q-mods>, <f-args>)
    endif
}
cnoreabbrev <expr> man getcmdtype() == ':' && getcmdpos() == 4 ? 'Man' : 'man'

command -nargs=? -complete=custom,man.GrepComplete ManGrep man.Grep(<q-args>)
cnoreabbrev <expr> mg getcmdtype() == ':' && getcmdpos() == 3 ? 'ManGrep' : 'mg'

augroup man
    autocmd!
    autocmd BufReadCmd man://* expand('<amatch>')->substitute('^man://', '', '')->man.ShellCmd()
augroup END

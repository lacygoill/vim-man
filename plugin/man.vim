vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

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

nno <space>o <cmd>call man#toc#show()<cr>

# For `-range=-1`, see:{{{
#
# https://github.com/neovim/neovim/commit/ba2e94d223d6cf4bd2594f6f2b2bfeb2aaa29368
# https://github.com/tpope/vim-scriptease/commit/d15112a77d0aa278f8ca88f07d53b018be79b585
#}}}
com -bang -bar -range=-1 -complete=customlist,man#complete -nargs=* Man
      \ if <bang>0
      |     &filetype = 'man'
      | else
      |     man#excmd(<count>, <q-mods>, <f-args>)
      | endif

augroup man | au!
    au BufReadCmd man://* expand('<amatch>')->substitute('^man://', '', '')->man#shellcmd()
augroup END

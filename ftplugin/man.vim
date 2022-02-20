vim9script noclear

if exists('b:did_ftplugin') || &filetype != 'man'
    finish
endif
b:did_ftplugin = true

import autoload 'man.vim'

&l:expandtab = false
&l:shiftwidth = 8
&l:softtabstop = 8
&l:tabstop = 8

&l:breakindent = true
&l:linebreak = true
&l:wrap = true

# Parentheses and '-' for references like `git-ls-files(1)`; '@' for systemd
# pages; ':' for Perl and C++ pages.  Here, I intentionally omit the locale
# specific characters matched by `@`.
&l:iskeyword = '@-@,:,a-z,A-Z,48-57,_,.,-,(,)'

&l:colorcolumn = '0'
&l:list = false
&l:number = false
&l:relativenumber = false

&l:tagfunc = 'man.GoToTag'

# TODO: Install  a  mapping which  would  manually  or automatically  display  a
# preview of the manpage reference under the cursor (use `p` for the lhs).
nnoremap <buffer><expr><nowait> q reg_recording() != '' ? 'q' : '<ScriptCmd>quit<CR>'
nnoremap <buffer><nowait> <CR> <C-]>
nnoremap <buffer><nowait> ) <ScriptCmd>man.JumpToRef()<CR>
nnoremap <buffer><nowait> ( <ScriptCmd>man.JumpToRef(false)<CR>

&l:foldcolumn = 0
&l:foldenable = true
&l:foldexpr = 'man.FoldExpr()'
&l:foldmethod = 'expr'
&l:foldnestmax = 1
&l:foldtext = 'man.FoldTitle()'

# If we press `u` by accident, we don't want to get back the deleted control characters.
# `:help clear-undo`
# TODO: Resetting `'modifiable'` would  be simpler, but it  doesn't work because
# this script  is sourced  in the  middle of  `man.InitPager()`, and  the latter
# saves/restores `'modifiable'`.  BTW,  the whole way this option  is handled by
# the autoload script looks confusing.  Anyway, find a way to reset it.
# Alternatively, consider asking for a `:clearundo` command (or function?).
#
#     var ul: number = &l:undolevels
#     &l:undolevels = -1
#     getline(1)->setline(1)
#     &l:undolevels = ul
#
# Update: The code is commented because it gives an error for `:Man` (not for `$ man`).
# When `:Man` is used, `'modifiable'` is reset.  But not when `$ man` is used.
# What a mess.  Make sure this option is set consistently.

b:undo_ftplugin = 'execute'
# TODO: Append commands to remove all our options/mappings?

vim9script

if exists('b:did_ftplugin') || &filetype != 'man'
    finish
endif
b:did_ftplugin = true

&l:expandtab = false
&l:tabstop = 8
&l:softtabstop = 8
&l:shiftwidth = 8

&l:wrap = true
&l:breakindent = true
&l:linebreak = true

# Parentheses and '-' for references like `git-ls-files(1)`; '@' for systemd
# pages; ':' for Perl and C++ pages.  Here, I intentionally omit the locale
# specific characters matched by `@`.
&l:iskeyword = '@-@,:,a-z,A-Z,48-57,_,.,-,(,)'


&l:number = false
&l:relativenumber = false
&l:foldcolumn = 0
&l:colorcolumn = '0'
&l:list = false
&l:foldenable = false

&l:tagfunc = 'man#gotoTag'

# TODO: Install  a  mapping which  would  manually  or automatically  display  a
# preview of the manpage reference under the cursor (use `p` for the lhs).
nnoremap <buffer><expr><nowait> q reg_recording() != '' ? 'q' : '<Cmd>quit<CR>'
nnoremap <buffer><nowait> <CR> <C-]>
nnoremap <buffer><nowait> ) <Cmd>call man#jumpToRef()<CR>
nnoremap <buffer><nowait> ( <Cmd>call man#jumpToRef(v:false)<CR>

&l:foldenable = true
&l:foldmethod = 'expr'
&l:foldexpr = 'man#foldexpr()'
&l:foldtext = 'fold#foldtext#get()'
&l:foldnestmax = 1

b:undo_ftplugin = 'execute'
# TODO: Append commands to remove all our options/mappings?

if exists('b:did_ftplugin') || &filetype !=# 'man'
    finish
endif
let b:did_ftplugin = 1

let s:pager = !exists('b:man_sect')

if s:pager
    call man#initPager()
endif

setl noswapfile buftype=nofile bufhidden=hide
setl nomodified readonly nomodifiable
setl noexpandtab tabstop=8 softtabstop=8 shiftwidth=8
setl wrap breakindent linebreak
" Parentheses and '-' for references like `git-ls-files(1)`; '@' for systemd
" pages; ':' for Perl and C++ pages.  Here, I intentionally omit the locale
" specific characters matched by `@`.
setl iskeyword=@-@,:,a-z,A-Z,48-57,_,.,-,(,)


setl nonumber norelativenumber
setl foldcolumn=0 colorcolumn=0 nolist nofoldenable

setl tagfunc=man#gotoTag

" TODO: Install  a  mapping which  would  manually  or automatically  display  a
" preview of the manpage reference under the cursor (use `p` for the lhs).
nno <buffer><expr><nowait> q reg_recording() != '' ? 'q' : '<cmd>q<cr>'
nno <buffer><nowait> <cr> <c-]>
nno <buffer><nowait> ) <cmd>call man#jumpToRef()<cr>
nno <buffer><nowait> ( <cmd>call man#jumpToRef(v:false)<cr>

setl foldenable
setl foldmethod=expr
setl foldexpr=man#foldexpr()
setl foldtext=fold#fdt#get()
setl foldnestmax=1

" TODO: Set `b:undo_ftplugin` so that it removes all our options/mappings?
let b:undo_ftplugin = ''

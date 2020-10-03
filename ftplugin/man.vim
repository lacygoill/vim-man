if exists('b:did_ftplugin') || &filetype !=# 'man'
    finish
endif
let b:did_ftplugin = 1

let s:pager = !exists('b:man_sect')

if s:pager
    call man#init_pager()
endif

setl noswapfile buftype=nofile bufhidden=hide
setl nomodified readonly nomodifiable
setl noexpandtab tabstop=8 softtabstop=8 shiftwidth=8
setl wrap breakindent linebreak
setl iskeyword+=-

setl nonumber norelativenumber
setl foldcolumn=0 colorcolumn=0 nolist nofoldenable

setl tagfunc=man#goto_tag

nno <buffer><expr><nowait><silent> q reg_recording() != '' ? 'q' : ':<c-u>q<cr>'

setl foldenable
setl foldmethod=expr
setl foldexpr=man#foldexpr()
setl foldtext=fold#fdt#get()
setl foldnestmax=1

let b:undo_ftplugin = ''

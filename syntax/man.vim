" TODO use backspaced text for better syntax highlighting.
" see https://github.com/neovim/neovim/pull/4449#issuecomment-234696194
"
" Also, read this:
" https://github.com/tweekmonster/neovim/commit/94a4b316516b92dcb8938b8b557c645abc9be79b
" The idea is to use the location to create an actionable TOC.
" Could be used in man pages but also in help files, and various documentation
" files (markdown notes?).
"
" We could create a mapping toggling the location window…
if exists('b:current_syntax')
    finish
endif

syntax case  ignore
syntax match manReference      display '[^()[:space:]]\+([0-9nx][a-z]*)'
syntax match manSectionHeading display '^\S.*$'
syntax match manTitle          display '^\%1l.*$'
syntax match manSubHeading     display '^ \{3\}\S.*$'
syntax match manOptionDesc     display '^\s\+\%(+\|-\)\S\+'

highlight default link manTitle          Title
highlight default link manSectionHeading Statement
highlight default link manOptionDesc     Constant
highlight default link manReference      PreProc
highlight default link manSubHeading     Function

if !exists('b:man_sect')
    call man#init_pager()
endif
if b:man_sect =~# '^[23]'
    syntax include @c $VIMRUNTIME/syntax/c.vim
    syntax match manCFuncDefinition display '\<\h\w*\>\ze\(\s\|\n\)*(' contained
    syntax region manSynopsis start='^\%(
                \SYNOPSIS\|
                \SYNTAX
                \\)$' end='^\%(\S.*\)\=\S$' keepend contains=manSectionHeading,@c,manCFuncDefinition
    highlight default link manCFuncDefinition Function
endif

" Prevent everything else from matching the last line
exe 'syntax match manFooter display "^\%'.line('$').'l.*$"'

let b:current_syntax = 'man'

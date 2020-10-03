if exists('b:current_syntax')
    finish
endif

syn case  ignore
syn match manReference      display '[^()[:space:]]\+([0-9nx][a-z]*)'
syn match manSectionHeading display '^\S.*$'
syn match manTitle          display '^\%1l.*$'
syn match manSubHeading     display '^ \{3\}\S.*$'
syn match manOptionDesc     display '^\s\+\%(+\|-\)\S\+'

hi def link manTitle          Title
hi def link manSectionHeading Statement
hi def link manOptionDesc     Constant
hi def link manReference      PreProc
hi def link manSubHeading     Function

" Don't move these highlight groups in the autoload script.{{{
"
" You would lose the highlighting when changing the color scheme while reading a
" man page.
"
"     $ man man
"     :colo default
"     " no highlighting for bold, italic, underline
"     :Man tac
"     " still no highlighting
"
" That's because a color scheme runs `:hi clear`.
" When we  change the color  scheme, we need to  make sure that  these highlight
" groups are re-installed.
"}}}
hi def manUnderline cterm=underline gui=underline
hi def manBold      cterm=bold      gui=bold
hi def manItalic    cterm=italic    gui=italic
" If you make these properties global, don't move them in the autload script.{{{
"
" It wouldn't work.
" When the autoload  script would be sourced, the highlight  groups on which the
" properties rely on would not be installed yet.  You would get get errors:
"
"     E970: Unknown highlight group name: 'manBold'
"     E970: Unknown highlight group name: 'manUnderline'
"     E970: Unknown highlight group name: 'manItalic'
"
" The properties would not be created,  and you would never get any highlighting
" for the bold/underline/italic styles.
"}}}
let s:buf = bufnr('%')
if prop_type_list(#{bufnr: s:buf})->index('manBold') == -1
    call prop_type_add('manBold', #{bufnr: s:buf, highlight: 'manBold'})
    call prop_type_add('manUnderline', #{bufnr: s:buf, highlight: 'manUnderline'})
    call prop_type_add('manItalic', #{bufnr: s:buf, highlight: 'manItalic'})
endif
unlet! s:buf

if &filetype !=# 'man'
    " May have been included by some other filetype.
    finish
endif

if !exists('b:man_sect')
    call man#init_pager()
endif

if b:man_sect =~# '^[023]'
  syn case match
  syn include @c $VIMRUNTIME/syntax/c.vim
  syn match manCFuncDefinition display '\<\h\w*\>\ze\(\s\|\n\)*(' contained
  syn match manLowerSentence /\n\s\{7}\l.\+[()]\=\%(\:\|.\|-\)[()]\=[{};]\@<!\n$/ display keepend contained contains=manReference
  syn region manSentence start=/^\s\{7}\%(\u\|\*\)[^{}=]*/ end=/\n$/ end=/\ze\n\s\{3,7}#/ keepend contained contains=manReference
  syn region manSynopsis start='^\%(
        \SYNOPSIS\|
        \SYNTAX\|
        \SINTASSI\|
        \SKŁADNIA\|
        \СИНТАКСИС\|
        \書式\)$' end='^\%(\S.*\)\=\S$' keepend contains=manLowerSentence,manSentence,manSectionHeading,@c,manCFuncDefinition
  hi def link manCFuncDefinition Function

  syn region manExample start='^EXAMPLES\=$' end='^\%(\S.*\)\=\S$' keepend contains=manLowerSentence,manSentence,manSectionHeading,manSubHeading,@c,manCFuncDefinition

  " XXX: groupthere doesn't seem to work
  syn sync minlines=500
  "syntax sync match manSyncExample groupthere manExample '^EXAMPLES\=$'
  "syntax sync match manSyncExample groupthere NONE '^\%(EXAMPLES\=\)\@!\%(\S.*\)\=\S$'
endif

" Prevent everything else from matching the last line
exe 'syntax match manFooter display "^\%' .. line('$') .. 'l.*$"'

let b:current_syntax = 'man'

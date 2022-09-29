vim9script noclear

if exists('b:current_syntax')
    finish
endif

syntax case  ignore
syntax match manReference      display '[^()[:space:]]\+([0-9nx][a-z]*)'
syntax match manSectionHeading display '^\S.*$'
syntax match manTitle          display '^\%1l.*$'
syntax match manSubHeading     display '^ \{3\}\S.*$'
syntax match manOptionDesc     display '^\s\+\(\%(+\|-\)\S\+,\s\+\)*\%(+\|-\)\S\+'

highlight default link manTitle          Title
highlight default link manSectionHeading Statement
highlight default link manOptionDesc     Constant
highlight default link manReference      PreProc
highlight default link manSubHeading     Function

# Don't move these highlight groups in the autoload script.{{{
#
# `manBold`, `manItalic`, `manUnderline` might be cleared when a color scheme is
# set.  That's because a color scheme can run `:highlight clear`.
# Note that the `default` argument does not help here; `:highlight clear` resets
# all highlight groups  to their default attributes.  And by  default, an ad-hoc
# group like `manBold` has no attributes; thus, it's cleared:
#
#     $ vim -Nu NONE +'highlight default MyGroup cterm=bold | highlight clear | highlight MyGroup'
#     MyGroup        xxx cleared
#}}}
highlight default manUnderline cterm=underline gui=underline
highlight default manBold      cterm=bold      gui=bold
highlight default manItalic    cterm=italic    gui=italic
# If you make these properties global, don't move them in the autload script.{{{
#
# It wouldn't work.
# When the autoload  script would be sourced, the highlight  groups on which the
# properties rely on would not be installed yet.  You would get errors:
#
#     E970: Unknown highlight group name: 'manBold'
#     E970: Unknown highlight group name: 'manUnderline'
#     E970: Unknown highlight group name: 'manItalic'
#
# The properties would not be created,  and you would never get any highlighting
# for the bold/underline/italic styles.
#}}}
var buf: number = bufnr('%')
if prop_type_get('manBold', {bufnr: buf}) == {}
    prop_type_add('manBold', {bufnr: buf, highlight: 'manBold'})
    prop_type_add('manUnderline', {bufnr: buf, highlight: 'manUnderline'})
    prop_type_add('manItalic', {bufnr: buf, highlight: 'manItalic'})
endif

if &filetype != 'man'
    # May have been included by some other filetype.
    finish
endif

if get(b:, 'man_sect', '') =~ '^[023]'
  syntax case match
  syntax include @c $VIMRUNTIME/syntax/c.vim
  syntax match manCFuncDefinition display '\<\h\w*\>\ze\(\s\|\n\)*(' contained
  syntax match manLowerSentence /\n\s\{7}\l.\+[()]\=\%(\:\|.\|-\)[()]\=[{};]\@<!\n$/ display keepend contained contains=manReference
  syntax region manSentence start=/^\s\{7}\%(\u\|\*\)[^{}=]*/ end=/\n$/ end=/\ze\n\s\{3,7}#/ keepend contained contains=manReference
  syntax region manSynopsis start='^\%(
        \SYNOPSIS\|
        \SYNTAX\|
        \SINTASSI\|
        \SKŁADNIA\|
        \СИНТАКСИС\|
        \書式\)$' end='^\%(\S.*\)\=\S$' keepend contains=manLowerSentence,manSentence,manSectionHeading,@c,manCFuncDefinition
  highlight default link manCFuncDefinition Function

  syntax region manExample start='^EXAMPLES\=$' end='^\%(\S.*\)\=\S$' keepend contains=manLowerSentence,manSentence,manSectionHeading,manSubHeading,@c,manCFuncDefinition

  # XXX: groupthere doesn't seem to work
  syntax sync minlines=500
  #     syntax sync match manSyncExample groupthere manExample '^EXAMPLES\=$'
  #     syntax sync match manSyncExample groupthere NONE '^\%(EXAMPLES\=\)\@!\%(\S.*\)\=\S$'
endif

# Prevent everything else from matching the last line
syntax match manFooter display '^.*\%$'

b:current_syntax = 'man'

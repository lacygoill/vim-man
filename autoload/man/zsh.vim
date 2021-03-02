vim9script noclear

def man#zsh#main(kwd: string) #{{{
    sil pages = systemlist('man -s1 -Kw ' .. shellescape(kwd) .. ' | grep zsh')
        ->map((_, v: string): string => matchstr(v, '.*/\zs.\{-}\ze\.'))
        ->filter((_, v: string): bool => v !~ '^\CNo manual entry for' && v != '')
    if len(pages) == 0
        return
    endif
    pos = 0
    exe 'Man ' .. pages[0]
enddef

var pages: list<string>

def man#zsh#moveInPages(dir: string) #{{{1
    if len(pages) == 0
        return
    endif
    pos = (pos + (dir == 'fwd' ? 1 : -1)) % len(pages)
    exe 'Man ' .. pages[pos]
endfu

var pos: number

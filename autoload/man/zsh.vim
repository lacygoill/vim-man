vim9script noclear

export def Main(kwd: string) #{{{
    silent pages = systemlist('man -s1 -Kw ' .. shellescape(kwd) .. ' | grep zsh')
        ->map((_, v: string) => v->matchstr('.*/\zs.\{-}\ze\.'))
        ->filter((_, v: string): bool => v !~ '^\CNo manual entry for' && v != '')
    if len(pages) == 0
        return
    endif
    pos = 0
    execute 'Man ' .. pages[0]
enddef

var pages: list<string>

export def MoveInPages(dir: string) #{{{1
    if len(pages) == 0
        return
    endif
    pos = (pos + (dir == 'fwd' ? 1 : -1)) % len(pages)
    execute 'Man ' .. pages[pos]
enddef

var pos: number

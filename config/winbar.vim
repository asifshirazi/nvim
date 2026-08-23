" Per-window buffer strip, drawn in 'winbar'.
"
" Sourced from init.vim section 5, replacing airline's tabline extension
" (config/airline.vim turns that one off). The built-in tabline cannot do this:
" 'tabline' and 'showtabline' are both global, and a tabpage *holds* windows
" rather than living inside one ("A tabpage holds one or more windows",
" tabpage.txt |tabpage-intro|). 'winbar' is the only bar Neovim draws per
" window, so it is the only place a per-pane list can go.
"
" Each window keeps its own list in w:winbar_bufs, oldest first. Window-local
" variables are not copied when a window splits, so a new pane starts with just
" the buffer it was opened on rather than inheriting its neighbour's history.

" ---- Tracking ----

function! s:Track() abort
  " Also the moment to (try to) build icon colours: opening the tree fires a
  " BufEnter, and only then are the NERDTree colour tables populated.
  call s:BuildIconHl()
  " No bar in NERDTree, terminals or quickfix. The test has to be on the
  " option, not the rendered text: the bar exists whenever 'winbar' is
  " non-empty, so returning an empty string from the function would still cost
  " those windows a screen line.
  if !buflisted(bufnr('')) || !empty(&buftype)
    setlocal winbar=
    return
  endif
  setlocal winbar=%!WinbarRender()
  " Append only when new, never move an existing entry to the end. Order is
  " first appearance, so a tab keeps its slot: an MRU order would reshuffle the
  " whole strip on every <Tab>, and make what the next press selects unguessable.
  let l:list = filter(get(w:, 'winbar_bufs', []), 'buflisted(v:val)')
  if index(l:list, bufnr('')) < 0
    let l:list += [bufnr('')]
  endif
  let w:winbar_bufs = l:list
endfunction

augroup winbar_bufs
  autocmd!
  autocmd BufWinEnter,BufEnter,WinEnter,TermOpen * call s:Track()
  " WinEnter is what catches `<C-w>v`, where the new pane shows a buffer it is
  " already in and so fires no Buf* event of its own.
  "
  " OptionSet catches the plugin windows: a NERDTree or terminal buffer is
  " often still buftype-less at BufEnter and only becomes nofile a moment
  " later, leaving a stale bar behind. It does not fire "during startup"
  " (autocmd.txt |OptionSet|), which costs nothing here, since no window has a
  " special buftype that early.
  autocmd OptionSet buftype call s:Track()
  " Icon colours and the modified marker are theme-derived highlight groups
  " (see the Colours section): build them once the UI is up, and rebuild on
  " every colourscheme change, when explicit highlights are wiped and the tab
  " background they carry moves with the theme.
  autocmd VimEnter * call s:BuildModifiedHl() | call s:BuildIconHl()
  autocmd ColorScheme * let s:icons_done = 0 | call s:BuildModifiedHl() | call s:BuildIconHl()
augroup END

" ---- Colours ----
"
" Icon colours reuse vim-nerdtree-syntax-highlight's own tables
" (config/plugins.vim), so the strip matches the tree exactly, limited subset
" and all (g:NERDTreeLimitedSyntax, config/nerdtree.vim:20). Those globals fill
" only once a NERDTree buffer has loaded its syntax, so s:BuildIconHl no-ops
" until then and s:Track keeps retrying it. The modified marker takes the
" theme's WarningMsg foreground instead, so it needs no plugin and tracks the
" theme. Every group carries the tab background (TabLine / TabLineSel) so a
" coloured glyph does not punch a differently-backed hole in the tab.
let s:icons_done = 0

function! s:TabBg(sel) abort
  let l:bg = synIDattr(synIDtrans(hlID(a:sel ? 'TabLineSel' : 'TabLine')), 'bg#')
  return empty(l:bg) ? 'NONE' : l:bg
endfunction

" First non-empty foreground among the groups, so a theme that leaves
" WarningMsg unset still yields a sensible marker colour.
function! s:GroupFg(names) abort
  for l:n in a:names
    let l:fg = synIDattr(synIDtrans(hlID(l:n)), 'fg#')
    if !empty(l:fg)
      return l:fg
    endif
  endfor
  return ''
endfunction

function! s:BuildModifiedHl() abort
  let l:fg = s:GroupFg(['WarningMsg', 'DiffChange', 'Special', 'Statement'])
  for l:sel in [0, 1]
    execute printf('hi WinbarModified%s guibg=%s %s',
          \ l:sel ? '_S' : '_N', s:TabBg(l:sel),
          \ empty(l:fg) ? 'guifg=NONE' : 'guifg=' . l:fg)
  endfor
endfunction

function! s:BuildIconHl() abort
  if s:icons_done | return | endif
  let l:colors = {}
  for l:d in [get(g:, 'NERDTreeExtensionHighlightColor', {}),
        \ get(g:, 'NERDTreeExactMatchHighlightColor', {}),
        \ get(g:, 'NERDTreePatternMatchHighlightColor', {})]
    for l:v in values(l:d)
      if !empty(l:v) | let l:colors[l:v] = 1 | endif
    endfor
  endfor
  if empty(l:colors) | return | endif
  for l:hex in keys(l:colors)
    for l:sel in [0, 1]
      execute printf('hi WinbarIcon_%s%s guifg=#%s guibg=%s',
            \ l:hex, l:sel ? '_S' : '_N', l:hex, s:TabBg(l:sel))
    endfor
  endfor
  let s:icons_done = 1
endfunction

" ---- Drawing ----

" Glyphs as escapes in DOUBLE quotes: single quotes take the backslash
" literally and put the characters on screen (see config/nerdtree.vim:16).
let s:close = "\U000F0156"     " nf-md-close, as config/keybinds.vim:129 uses
" BLACK CIRCLE is plain Unicode rather than a Nerd Font private-use glyph, so
" it renders without a patched font.
let s:modified = "\u25CF"

" vim-devicons only defines this once its own plugin file has been sourced,
" which is after init.vim finishes. Drawing happens long after that, but the
" guard also covers the plugin being removed.
function! s:Icon(buf) abort
  if !exists('*WebDevIconsGetFileTypeSymbol')
    return ''
  endif
  return WebDevIconsGetFileTypeSymbol(bufname(a:buf))
endfunction

" The colour the tree would give this file: exact filename, then pattern, then
" extension (most specific first). Empty when the extension is outside the
" coloured subset, which is exactly when the tree leaves its icon uncoloured.
function! s:IconColor(buf) abort
  let l:name = tolower(fnamemodify(bufname(a:buf), ':t'))
  if empty(l:name) | return '' | endif
  let l:hex = get(get(g:, 'NERDTreeExactMatchHighlightColor', {}), l:name, '')
  if !empty(l:hex) | return l:hex | endif
  for [l:pat, l:val] in items(get(g:, 'NERDTreePatternMatchHighlightColor', {}))
    if !empty(l:val) && l:name =~ '\c' . l:pat
      return l:val
    endif
  endfor
  return get(get(g:, 'NERDTreeExtensionHighlightColor', {}), tolower(fnamemodify(l:name, ':e')), '')
endfunction

" The prebuilt group for this colour, or '' if it was never built (tree not yet
" opened): the caller then leaves the icon in the tab's own colour.
function! s:IconHl(hex, sel) abort
  let l:g = 'WinbarIcon_' . a:hex . (a:sel ? '_S' : '_N')
  return hlexists(l:g) ? l:g : ''
endfunction

function! WinbarRender() abort
  " A '%!' expression is evaluated in the context of the *current* window, not
  " the one being drawn ("evaluated in the context of the current window and
  " buffer", options.txt |stl-%!|), so a bare w: here would read the focused
  " pane for every pane. g:statusline_winid, set by the same mechanism, names
  " the window this bar belongs to.
  let l:win = get(g:, 'statusline_winid', win_getid())
  let l:cur = winbufnr(l:win)
  let l:out = ''
  for l:buf in getwinvar(l:win, 'winbar_bufs', [])
    if !buflisted(l:buf) | continue | endif
    let l:sel = (l:buf == l:cur)
    let l:tab = l:sel ? 'TabLineSel' : 'TabLine'
    let l:name = fnamemodify(bufname(l:buf), ':t')
    let l:name = empty(l:name) ? '[No Name]' : l:name
    " Colour the icon from the tree's own table, dropping back to the tab
    " colour both when there is no icon and when the extension is uncoloured.
    let l:icon = s:Icon(l:buf)
    if empty(l:icon)
      let l:label = l:name
    else
      let l:hl = s:IconHl(s:IconColor(l:buf), l:sel)
      let l:label = empty(l:hl)
            \ ? l:icon . ' ' . l:name
            \ : printf('%%#%s#%s%%#%s# %s', l:hl, l:icon, l:tab, l:name)
    endif
    " Two click regions per tab, each ended with its own %X: the label switches
    " to the buffer, the trailing glyph closes the tab. A modified buffer shows
    " the dot in the theme's warning colour instead of the close glyph.
    let l:mark = getbufvar(l:buf, '&modified')
          \ ? printf('%%#WinbarModified%s#%s%%#%s#', l:sel ? '_S' : '_N', s:modified, l:tab)
          \ : s:close
    let l:out .= '%#' . l:tab . '#'
          \ . printf('%%%d@WinbarClick@ %s %%X', l:buf, l:label)
          \ . printf('%%%d@WinbarClose@%s %%X', l:buf, l:mark)
  endfor
  return l:out . '%#TabLineFill#'
endfunction

" ---- Clicking ----

" Left click switches, middle click closes. Closing drops the buffer from THIS
" pane's strip only and leaves it loaded, so a modified tab can be closed
" without losing anything ('hidden' is on). Killing the buffer outright is
" <C-q>'s job (config/keybinds.vim), which has to work around :bdelete closing
" the window.
" Which pane was clicked has to be asked for, not assumed: "Use
" getmousepos().winid in the specified function to get the corresponding
" window-ID of the clicked item" (options.txt, the %@ item). That lookup is the
" one part of this that needs a real mouse, so both handlers keep it to a line
" and hand the window to WinbarDrop, which is drivable from a test.
function! WinbarClick(bufnr, clicks, button, mods) abort
  let l:win = getmousepos().winid
  if l:win <= 0 | return | endif
  if a:button ==# 'm'
    call WinbarDrop(l:win, a:bufnr)
  else
    call win_gotoid(l:win)
    execute 'buffer' a:bufnr
  endif
endfunction

" The close glyph at the right of each tab.
function! WinbarClose(bufnr, clicks, button, mods) abort
  let l:win = getmousepos().winid
  if l:win <= 0 | return | endif
  call WinbarDrop(l:win, a:bufnr)
endfunction

function! WinbarDrop(win, bufnr) abort
  if win_id2win(a:win) == 0
    return
  endif
  call win_gotoid(a:win)
  if bufnr('') != a:bufnr
    call filter(w:winbar_bufs, 'v:val != ' . a:bufnr)
    " Nothing moved, so nothing would trigger a repaint on its own.
    redrawstatus
    return
  endif
  " Dropping the buffer on display means moving off it first, or the pane would
  " show a file its own strip no longer lists. Land on the neighbour that slides
  " into the closed tab's slot, the way closing a tab anywhere else behaves.
  let l:slot = index(w:winbar_bufs, a:bufnr)
  let l:rest = filter(copy(w:winbar_bufs), 'v:val != ' . a:bufnr)
  if empty(l:rest)
    enew
  else
    execute 'buffer' l:rest[min([l:slot, len(l:rest) - 1])]
  endif
  " s:Track ran on that switch and rebuilt the list with a:bufnr still in it.
  call filter(w:winbar_bufs, 'v:val != ' . a:bufnr)
endfunction

" ---- Cycling (<Tab> / <S-Tab>, mapped in config/keybinds.vim) ----

function! s:Cycle(step) abort
  let l:list = filter(get(w:, 'winbar_bufs', []), 'buflisted(v:val)')
  if len(l:list) < 2 | return | endif
  " Vim's % truncates toward zero, so index 0 stepping back gives -1, and a
  " negative list index counts from the end. The wrap falls out for free.
  execute 'buffer' l:list[(index(l:list, bufnr('')) + a:step) % len(l:list)]
endfunction

" Two named wrappers rather than one function taking a direction: which-key
" matches its icon rules against the lowercased mapping text
" (which-key.nvim/lua/which-key/icons.lua:177), and a Lua pattern would read
" the parentheses of a WinbarCycle(1) as a capture group.
function! WinbarNext() abort
  call s:Cycle(1)
endfunction

function! WinbarPrev() abort
  call s:Cycle(-1)
endfunction

" ---- Sessions ----
"
" :mksession cannot carry these lists. 'sessionoptions' has no word for
" window-local variables at all: its only variable word is `globals`, which
" takes g: names that "start with an uppercase letter and contain at least one
" lowercase letter. Only String and Number types are stored" (options.txt), so
" a w: List is excluded twice over. Both savers ask for the lines below
" instead. autoload/restart.vim appends them to its own session file, and
" auto-session returns them from save_extra_cmds (init.vim section 9), which
" lands in the session's companion x.vim: "If a file exists with the same name
" as the Session file, but ending in "x.vim" (for eXtra), executes that as
" well" (starting.txt, :mksession step 10). Either route runs them after the
" whole layout is back.

function! WinbarSessionLines() abort
  let l:spec = []
  for l:win in nvim_list_wins()
    let l:names = []
    for l:buf in getwinvar(l:win, 'winbar_bufs', [])
      if buflisted(l:buf) && !empty(bufname(l:buf))
        call add(l:names, fnamemodify(bufname(l:buf), ':p'))
      endif
    endfor
    " Paths, not buffer numbers: numbers are handed out in load order and mean
    " something different after the restart.
    let l:cur = bufname(winbufnr(l:win))
    " One entry is whatever s:Track would rebuild by itself, so only a real
    " strip is worth writing down.
    if len(l:names) > 1 && !empty(l:cur)
      call add(l:spec, [fnamemodify(l:cur, ':p'), l:names])
    endif
  endfor
  if empty(l:spec)
    return []
  endif
  return [
        \ '',
        \ '" added by :Restart / auto-session -- rebuild the per-window buffer',
        \ '" strips (config/winbar.vim), which mksession cannot carry.',
        \ 'if exists("*WinbarRestore") | call WinbarRestore(' . string(l:spec) . ') | endif',
        \ ]
endfunction

function! WinbarRestore(spec) abort
  let l:by_name = {}
  for l:buf in getbufinfo({'buflisted': 1})
    if !empty(l:buf.name)
      let l:by_name[l:buf.name] = l:buf.bufnr
    endif
  endfor
  " Windows are matched by the file they are showing, never by number: the
  " NERDTree rebuild closes and reopens its pane, which renumbers everything
  " after it. Each window is claimed once, so two panes on the same file take
  " their strips in order.
  let l:claimed = {}
  for [l:cur, l:names] in a:spec
    for l:win in nvim_list_wins()
      if has_key(l:claimed, l:win)
            \ || fnamemodify(bufname(winbufnr(l:win)), ':p') !=# l:cur
        continue
      endif
      let l:list = []
      for l:name in l:names
        if has_key(l:by_name, l:name) && index(l:list, l:by_name[l:name]) < 0
          call add(l:list, l:by_name[l:name])
        endif
      endfor
      " Whatever the session said, the window's own buffer belongs in its
      " strip: the bar highlights it as the current tab.
      if index(l:list, winbufnr(l:win)) < 0
        call add(l:list, winbufnr(l:win))
      endif
      call setwinvar(l:win, 'winbar_bufs', l:list)
      let l:claimed[l:win] = 1
      break
    endfor
  endfor
  redrawstatus!
endfunction

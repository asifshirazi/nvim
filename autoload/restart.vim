" ============================================================================
" :Restart -- restart Nvim, restoring the whole layout
" ============================================================================
" Loaded on demand: nothing here runs until restart#run() is first called, so
" this file costs nothing at startup.
"
" :restart (Nvim 0.12+) quits, re-execs the server with the same argv and
" reattaches the UI; :mksession captures tabs, windows, buffers and NERDTree.
" A running process can't be checkpointed, so terminal panes would relaunch
" from scratch -- rewrite their commands to resume the previous session instead.

let s:session_file = stdpath('state') . '/restart-session.vim'
let s:resumable = ['claude', 'pi', 'omp']   " CLIs whose sessions survive via --continue

" All three CLIs store sessions per working directory, under a mangled directory
" name. Passing --continue with no saved session makes them abort, so only add
" the flag when one actually exists -- worst case you get a fresh session,
" which is just the normal behaviour.
function! s:has_session(cmd, cwd) abort
  let l:cwd = fnamemodify(expand(a:cwd), ':p:h')
  if a:cmd ==# 'claude'        " ~/.claude/projects/<cwd with / and . as ->
    let l:dir = expand('~/.claude/projects/') . substitute(l:cwd, '[/.]', '-', 'g')
  elseif a:cmd ==# 'pi'        " ~/.pi/agent/sessions/-<cwd+/ with / as ->-
    let l:dir = expand('~/.pi/agent/sessions/-') . substitute(l:cwd . '/', '/', '-', 'g') . '-'
  elseif a:cmd ==# 'omp'       " ~/.omp/agent/sessions/<$HOME-relative cwd, / as ->
    let l:home = substitute(expand('~'), '/$', '', '')
    let l:rel = (l:cwd ==# l:home || stridx(l:cwd, l:home . '/') == 0)
          \ ? l:cwd[len(l:home):] : l:cwd
    let l:dir = expand('~/.omp/agent/sessions/') . substitute(l:rel, '/', '-', 'g')
  else
    return 0
  endif
  return !empty(glob(l:dir . '/*.jsonl', 1, 1))
endfunction

" :mksession records that a NERDTree window existed, but not which folders were
" expanded -- the tree comes back collapsed to its root. Walk the live tree for
" directory nodes with isOpen set, so the restore can reopen exactly those.
function! s:collect_open(node, acc) abort
  for l:child in get(a:node, 'children', [])
    if l:child.path.isDirectory
      if get(l:child, 'isOpen', 0)
        call add(a:acc, l:child.path.str())
      endif
      call s:collect_open(l:child, a:acc)
    endif
  endfor
endfunction

function! restart#open_dirs() abort
  " Scan every buffer, not just windows in the current tab: g:NERDTree.IsOpen()
  " is false when the tree lives in another tabpage, which would silently skip
  " the whole capture.
  let l:paths = []
  for l:b in getbufinfo()
    let l:tree = getbufvar(l:b.bufnr, 'NERDTree')
    if !empty(l:tree) && has_key(l:tree, 'root')
      call s:collect_open(l:tree.root, l:paths)
      break
    endif
  endfor
  " Shortest first: findNode() only walks cached children, so a parent must be
  " opened before its subdirectories can be found.
  return sort(l:paths, {a, b -> len(a) - len(b)})
endfunction

" A pane opened as a plain `:terminal` and then used to launch claude/pi by
" hand records only the shell (term://cwd//PID:/bin/zsh) -- nvim never knew
" about the child process, so the restore gives you a bare shell. Look for a
" resumable CLI among the shell's descendants and record that instead.
function! s:resumable_descendant(pid, depth) abort
  if a:depth > 3
    return ''
  endif
  for l:kid in split(system('pgrep -P ' . shellescape(a:pid)), "\n")
    let l:kid = trim(l:kid)
    if empty(l:kid)
      continue
    endif
    let l:name = fnamemodify(trim(system('ps -o comm= -p ' . shellescape(l:kid))), ':t')
    if index(s:resumable, l:name) >= 0
      return l:name
    endif
    let l:deeper = s:resumable_descendant(l:kid, a:depth + 1)
    if !empty(l:deeper)
      return l:deeper
    endif
  endfor
  return ''
endfunction

" Returns {session-file buffer name -> replacement name}
function! s:terminal_overrides() abort
  let l:map = {}
  for l:b in getbufinfo()
    if getbufvar(l:b.bufnr, '&buftype') !=# 'terminal' || empty(l:b.name)
      continue
    endif
    " Already records a resumable CLI -- the normal path handles it
    if l:b.name =~# ':\%(' . join(s:resumable, '\|') . '\)\>'
      continue
    endif
    let l:pid = getbufvar(l:b.bufnr, 'terminal_job_pid', 0)
    let l:cmd = empty(l:pid) ? '' : s:resumable_descendant(l:pid, 0)
    if empty(l:cmd)
      continue
    endif
    let l:base = matchstr(l:b.name, '^term://.\{-}//\d\+:')
    let l:cwd = matchstr(l:b.name, '^term://\zs.\{-}\ze//\d\+:')
    let l:map[l:b.name] = l:base . l:cmd
          \ . (s:has_session(l:cmd, l:cwd) ? '\ --continue' : '')
  endfor
  return l:map
endfunction

" Rewrite resumable-CLI terminal commands in SESSION LINES to add --continue
" wherever a saved session exists, with both fix-ups: the regex handles panes
" launched as the CLI directly, s:terminal_overrides the shells running one as
" a child. Shared by restart#save() and the auto-session post_save hook
" (init.vim section 9), so both restore paths resume the same sessions. The
" \@! guard means a name already ending in --continue is left alone, so
" re-saving a restored layout never stacks the flag.
function! s:resume_rewrite(lines) abort
  " Terminal buffers are stored as  term://{cwd}//{pid}:{cmd}\ {args}
  let l:pattern = 'term://\(.\{-}\)//\d\+:\(' . join(s:resumable, '\|') . '\)'
        \ . '\%(\\ --continue\)\@!\ze\%(\\ \|\>\)'
  call map(a:lines, {_, l -> substitute(l, l:pattern,
        \ '\=submatch(0) . (s:has_session(submatch(2), submatch(1)) ? "\\ --continue" : "")', 'g')})
  " Shell panes running a resumable CLI as a child (see s:terminal_overrides)
  for [l:name, l:replacement] in items(s:terminal_overrides())
    let l:from = escape(substitute(l:name, ' ', '\\ ', 'g'), '\')
    call map(a:lines, {_, l -> substitute(l, '\V' . l:from, escape(l:replacement, '\&~'), 'g')})
  endfor
  return a:lines
endfunction

" Patch a just-written session file in place. auto-session's post_save hook
" passes it v:this_session, which mksession sets to the file it wrote.
function! restart#resume_patch(path) abort
  if empty(a:path) || !filereadable(a:path)
    return
  endif
  call writefile(s:resume_rewrite(readfile(a:path)), a:path)
endfunction

" Write the session file, with the two fix-ups above applied.
function! restart#save() abort
  execute 'mksession!' fnameescape(s:session_file)
  let l:lines = s:resume_rewrite(readfile(s:session_file))
  " Reopen the folders that were expanded (see restart#open_dirs above).
  " Emitted whenever a tree was open -- even with nothing expanded -- because
  " the block also replaces the stale restored tree (see below).
  let l:open = restart#open_dirs()
  let l:had_tree = !empty(filter(getbufinfo(), 'v:val.name =~# "NERD_tree_"'))
  if l:had_tree
    let l:lines += [
          \ '',
          \ '" added by :Restart -- rebuild NERDTree and reopen expanded folders.',
          \ '" mksession restores the tree buffer, but NERDTree never registers it',
          \ '" (t:NERDTreeBufName is tab-local and is not saved), so the restored tree',
          \ '" is inert: <C-t> opens a SECOND tree instead of toggling it, and its',
          \ '" folders cannot be driven. Drop the stale buffer, open a real tree.',
          \ 'function! s:RestoreNerdTree() abort',
          \ '  let l:log = []',
          \ '  let l:want = ' . string(l:open),
          \ '  let l:prev = win_getid()',
          \ '  let l:stale = filter(getbufinfo(), ''v:val.name =~# "NERD_tree_"'')',
          \ '  for l:b in l:stale',
          \ '    for l:wid in win_findbuf(l:b.bufnr)',
          \ '      if win_getid() != l:wid && winnr("$") > 1',
          \ '        call win_gotoid(l:wid)',
          \ '        noautocmd close',
          \ '      endif',
          \ '    endfor',
          \ '    silent! execute "bwipeout!" l:b.bufnr',
          \ '  endfor',
          \ '  call add(l:log, "stale tree buffers dropped: " . len(l:stale))',
          \ '  " t:NERDTreeBufName still names the wiped buffer; createTabTree() would',
          \ '  " then try to Close() a dead tree and never build the new one.',
          \ '  unlet! t:NERDTreeBufName',
          \ '  if win_id2win(l:prev) | call win_gotoid(l:prev) | endif',
          \ '  try',
          \ '    call add(l:log, "pre-open: win=" . winnr() . "/" . winnr("$") . " buf=" . bufname("%") . " bt=" . &buftype . " ExistsForTab=" . g:NERDTree.ExistsForTab())',
          \ '    try',
          \ '      silent NERDTree',
          \ '    catch',
          \ '      call add(l:log, "  :NERDTree threw: " . v:exception)',
          \ '    endtry',
          \ '    call add(l:log, "after :NERDTree buf=" . bufname("%") . " ft=" . &filetype)',
          \ '    " Do not assume :NERDTree left the cursor in the tree window',
          \ '    if !exists("b:NERDTree")',
          \ '      for l:w in range(1, winnr("$"))',
          \ '        if !empty(getbufvar(winbufnr(l:w), "NERDTree"))',
          \ '          noautocmd execute l:w . "wincmd w"',
          \ '          break',
          \ '        endif',
          \ '      endfor',
          \ '    endif',
          \ '    if !exists("b:NERDTree")',
          \ '      call add(l:log, "NO LIVE TREE after :NERDTree -- giving up")',
          \ '      return l:log',
          \ '    endif',
          \ '    call add(l:log, "opened fresh tree, root: " . b:NERDTree.root.path.str())',
          \ '    let l:opened = 0',
          \ '    for l:p in l:want',
          \ '      let l:n = b:NERDTree.root.findNode(g:NERDTreePath.New(l:p))',
          \ '      if empty(l:n)',
          \ '        call add(l:log, "  NOT FOUND: " . l:p)',
          \ '      elseif l:n.path.isDirectory',
          \ '        call l:n.open()',
          \ '        let l:opened += 1',
          \ '      endif',
          \ '    endfor',
          \ '    call b:NERDTree.render()',
          \ '    call add(l:log, "folders reopened: " . l:opened . "/" . len(l:want))',
          \ '  catch',
          \ '    call add(l:log, "EXCEPTION: " . v:exception)',
          \ '  finally',
          \ '    if win_id2win(l:prev) | call win_gotoid(l:prev) | endif',
          \ '  endtry',
          \ '  return l:log',
          \ 'endfunction',
          \ 'call writefile(s:RestoreNerdTree(), stdpath("state") . "/restart-nerdtree.log")',
          \ ]
  endif
  " NERDTree's restore swaps its placeholder buffer for the real tree, leaving
  " the empty original listed but windowless -- an unwanted [No Name] tab.
  let l:lines += [
        \ '',
        \ '" added by :Restart -- drop empty unnamed buffers left by the restore',
        \ 'for s:b in getbufinfo({"buflisted": 1})',
        \ '  if empty(s:b.name) && empty(s:b.windows) && !s:b.changed',
        \ '    silent! execute "bwipeout" s:b.bufnr',
        \ '  endif',
        \ 'endfor',
        \ 'unlet! s:b',
        \ ]
  " Per-window buffer strips (config/winbar.vim). Appended last so the lists
  " resolve against the final buffer set: the NERDTree block above wipes the
  " stale tree buffer and the block above that drops the empty unnamed ones.
  let l:lines += WinbarSessionLines()
  call writefile(l:lines, s:session_file)
  return s:session_file
endfunction

" auto-session auto-restores at VimEnter whenever nvim starts with no file
" arguments -- exactly what :restart does. Its restore would run first and ours
" on top. The `silent only` / `silent tabonly` at the head of a session file
" hides the duplicated *windows*, but not the buffers, and it does not kill
" terminal jobs: you would end up with two claude, two pi and two omp
" processes, one set alive but hidden. Drop a sentinel the pre_restore hook in
" init.vim checks, so auto-session stands down for this one restart.
let s:skip_flag = stdpath('state') . '/restart-skip-autosession'

function! restart#run() abort
  echomsg 'restart: restoring everything'
        \ . ' (layout, NERDTree folders, claude/pi/omp sessions)'
  call restart#save()
  call writefile([localtime()], s:skip_flag)
  execute 'restart source' fnameescape(s:session_file)
endfunction

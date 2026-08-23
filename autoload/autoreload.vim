" ============================================================================
" Auto-detect external file changes
" ============================================================================
" Unlike autoload/restart.vim this is not lazy -- init.vim calls
" autoreload#enable() at startup, because the timer has to be running before
" anything external touches a file. Kept here to stay out of init.vim.
"
" 'autoread' only reloads a buffer when something asks it to, via :checktime.
" The usual autocmd triggers all depend on *you*: FocusGained needs Nvim to
" regain OS focus, BufEnter needs you to enter the window, and CursorHold never
" fires while you're typing in a terminal pane. So poll on a timer as well --
" that's what reloads a file edited outside Nvim without clicking into it.

let s:timer = -1

function! s:tick(...) abort
  " :checktime throws inside the command-line window (q: / q/)
  if getcmdwintype() !=# ''
    return
  endif
  silent! checktime
endfunction

" ---- NERDTree ----
" NERDTree has no auto-refresh setting: its help documents only r, R and
" :NERDTreeRefreshRoot, and none of the plugin's own autocmds watch the
" filesystem. s:refreshRoot() is a recursive rescan + full render (its own code
" warns 'This could take a while'), so it is deliberately NOT on the timer --
" refresh when you enter the tree, and after a write.
let s:refreshing = 0

function! s:refresh_nerdtree() abort
  " Bail out while a tree is being built: _createTreeWin() names the buffer
  " (NERD_tree_tab_N) before _createNERDTree() sets b:NERDTree, and a BufEnter
  " landing in that gap would refresh a half-built tree -- leaving it with no
  " filetype and no tree object, so <C-t> opens a second tree instead of
  " toggling it.
  if bufname('%') =~# 'NERD_tree_' && !exists('b:NERDTree')
    return
  endif
  if s:refreshing || !exists('g:NERDTree') || !g:NERDTree.IsOpen()
    return
  endif
  let s:refreshing = 1
  try
    " silent: refreshRoot echoes "Refreshing the root node..." on every call
    silent NERDTreeRefreshRoot
  finally
    let s:refreshing = 0
  endtry
endfunction

function! autoreload#enable(...) abort
  let l:interval = a:0 ? a:1 : 1000

  augroup autoreload
    autocmd!
    autocmd FocusGained * checktime
    autocmd CursorHold,CursorHoldI * checktime
    autocmd BufEnter * checktime
    " Keep the file tree in step with the filesystem
    autocmd BufEnter NERD_tree_* call s:refresh_nerdtree()
    autocmd BufWritePost * call s:refresh_nerdtree()
  augroup END

  " Re-sourcing init.vim must not stack timers
  if s:timer == -1
    let s:timer = timer_start(l:interval, function('s:tick'), {'repeat': -1})
  endif
  return s:timer
endfunction

function! autoreload#disable() abort
  autocmd! autoreload
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
endfunction

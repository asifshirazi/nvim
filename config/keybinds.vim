" Map Ctrl+B to toggle the sidebar explorer open and closed
"nnoremap <C-b> :Lexplore<CR>

" Toggle NERDTree sidebar with Ctrl+t
nnoremap <silent> <C-t> :NERDTreeToggle<CR>

" Switch to the NEXT tab with Tab 
nnoremap <Tab> :bnext<CR>
" Switch to the PREVIOUS tab with Shift+Tab
nnoremap <S-Tab> :bprevious<CR>

" Alternatively, use Ctrl + q to close a tab (buffer) without closing the window
" Plain :bdelete closes the window when it's the last listed buffer, which then
" leaves NERDTree as the only window -- and the autocmd in init.vim quits nvim.
function! s:CloseBuffer() abort
  let l:cur = bufnr('%')
  if getbufvar(l:cur, '&modified')
    echohl ErrorMsg | echo 'Buffer has unsaved changes' | echohl None
    return
  endif
  let l:others = filter(range(1, bufnr('$')),
        \ 'buflisted(v:val) && v:val != l:cur')
  let l:back = win_getid()
  for l:win in win_findbuf(l:cur)
    call win_gotoid(l:win)
    if empty(l:others)
      enew
    else
      bprevious
      if bufnr('%') ==# l:cur | enew | endif
    endif
  endfor
  call win_gotoid(l:back)
  if bufexists(l:cur)
    execute 'bdelete' l:cur
  endif
endfunction
nnoremap <silent> <C-q> :call <SID>CloseBuffer()<CR>


" ---- Leader mappings (leader is \ -- mapleader is unset, so Vim's default) ----
" Ranger is NOT mapped here: ranger.vim already does `map <leader>f :Ranger<CR>`
" (plugin/ranger.vim:139). Mapping it again would just shadow its own key.
" theme=dropdown -- centred box, no preview pane (telescope.txt THEMES).
" Using the command form rather than a telescope.setup block: with no other
" telescope config to hold, a `pickers = { find_files = ..., ... }` block would
" exist solely to carry the theme for each of these three.
nnoremap <leader>tf <cmd>Telescope find_files theme=dropdown<cr>
nnoremap <leader>ts <cmd>Telescope live_grep theme=dropdown<cr>
" theme=ivy -- bottom panel with a preview (telescope/themes.lua:104), which
" suits a status list better than a centred box.
nnoremap <leader>tgs <cmd>Telescope git_status<cr>

" Colorscheme picker (see init.vim section 6 for the theme list)
nnoremap <silent> <leader>h <cmd>Themery<cr>

" Dev layout: NERDTree left, file middle, claude top-right, pi bottom-right
nnoremap <silent> <leader>d :NERDTreeFind<CR><C-w>p:vertical botright 120new<CR>:terminal claude<CR>:belowright 30new<CR>:terminal pi<CR><C-w>t<C-w>l

" Small terminal panel below the current window (10 lines), cursor lands in it
nnoremap <silent> <leader>c <cmd>belowright 10split +terminal<cr>

nnoremap <silent> <leader>R <cmd>Restart<cr>

" ---- which-key.nvim ----
" The menu appears on its own once you press \ and pause for 'timeoutlen'
" (250ms here) -- no prefix mapping needed.
" sort = { 'manual' } keeps the order listed below; the previous plugin sorted
" keys alphabetically with no way to override.
lua << EOF
-- No icon provider (mini.icons / nvim-web-devicons) is installed on purpose.
-- which-key only consults one for rules that use cat+name (icons.lua:110);
-- every icon here supplies a literal glyph, which returns at icons.lua:108
-- before any provider is asked. :checkhealth which-key will warn about this --
-- the warning is expected, not a fault.
local wk = require('which-key')
-- icons.rules extends the built-in rules (icons.lua). Ours are matched FIRST
-- (icons.lua:205), against desc:lower() via Lua find (icons.lua:177) -- so the
-- patterns are lowercase, and kept narrow so they don't shadow the built-in
-- search/window/buffer rules that already resolve.
wk.setup {
  sort = { 'manual' },
  icons = {
    rules = {
      -- operators
      { pattern = 'yank', icon = '󰆏', color = 'yellow' },
      { pattern = 'delete', icon = '󰆴', color = 'red' },
      { pattern = 'change', icon = '󰏫', color = 'orange' },
      { pattern = 'replace', icon = '󰛔', color = 'orange' },
      { pattern = 'indent', icon = '󰉶', color = 'cyan' },
      { pattern = 'toggle case', icon = '󰬴', color = 'purple' },
      { pattern = 'visual', icon = '󰒉', color = 'purple' },
      -- motions
      { pattern = 'word', icon = '󰬗', color = 'azure' },
      { pattern = 'char', icon = '󰬊', color = 'azure' },
      { pattern = 'empty line', icon = '󰌑', color = 'grey' },
      { pattern = 'of line', icon = '󰑀', color = 'grey' },
      -- misc entries in the built-in popup
      { pattern = 'keymaps', icon = '󰌌', color = 'grey' },
      { pattern = 'help', icon = '󰋖', color = 'blue' },
      { pattern = 'run program', icon = '󰐊', color = 'green' },
      -- this config's own commands
      { pattern = 'nerdtree', icon = '󰙅', color = 'green' },
      { pattern = 'closebuffer', icon = '󰅖', color = 'red' },
      { pattern = 'bnext', icon = '󰮱', color = 'cyan' },
      { pattern = 'bprevious', icon = '󰮲', color = 'cyan' },
    },
  },
}
-- Icons set explicitly, written as \u{...} escapes rather than literal glyphs
-- so nothing can strip them in transit. An explicit icon short-circuits rule
-- matching (icons.lua:108 -- and an EMPTY string is truthy in Lua, which is how
-- these silently rendered blank before).
wk.add {
  { '<leader>f', desc = 'Ranger', icon = { icon = '\u{f024b}', color = 'yellow' } },                       -- nf-md-folder; mapped by ranger.vim
  { '<leader>t', group = 'telescope', icon = { icon = '\u{f0b4e}', color = 'blue' } },                     -- nf-md-telescope
  { '<leader>tf', desc = 'Find files', icon = { icon = '\u{f021e}', color = 'blue' } },                    -- nf-md-file_find
  { '<leader>ts', desc = 'Search in files', icon = { icon = '\u{f13b8}', color = 'blue' } },               -- nf-md-text_search
  { '<leader>tg', group = 'git', icon = { icon = '\u{f02a2}', color = 'orange' } },                        -- nf-md-git
  { '<leader>tgs', desc = 'Git status', icon = { icon = '\u{f062c}', color = 'orange' } },                 -- nf-md-source_branch
  { '<leader>h', desc = 'Themery (colorscheme)', icon = { icon = '\u{f03d8}', color = 'purple' } },        -- nf-md-palette
  { '<leader>d', desc = 'Development mode', icon = { icon = '\u{f0bcc}', color = 'orange' } },             -- nf-md-view_split_vertical
  { '<leader>c', desc = 'Terminal', icon = { icon = '\u{f018d}', color = 'red' } },                        -- nf-md-console
  { '<leader>R', desc = 'Restart (restore everything)', icon = { icon = '\u{f0450}', color = 'green' } },  -- nf-md-refresh
  { '<leader>b', group = 'buffer', icon = { icon = '\u{f0219}', color = 'cyan' } },                        -- nf-md-file_document; mapped by bclose.vim
  { '<leader>bd', desc = 'Close buffer', icon = { icon = '\u{f0156}', color = 'cyan' } },                  -- nf-md-close
}
EOF

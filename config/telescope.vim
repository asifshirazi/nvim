" Puts NERDTree's `m` menu into a Telescope picker. The original echo-driven
" menu stays on `M`.
"
" Sourced from init.vim section 7, but the key maps are registered from a
" VimEnter autocmd at the bottom rather than immediately. NERDTreeAddKeyMap()
" does not exist while init.vim runs: vim-plug only sets &runtimepath, and the
" file defining it is sourced afterwards. That same file calls
" postSourceActions() as its last act (plugin/NERD_tree.vim:235), which creates
" the default bindings, so by VimEnter the default `m` exists and 'override'
" can replace it. VimEnter still lands before any tree is built, so the very
" first tree gets these: Creator._bindMappings() calls KeyMap.BindAll() once
" per tree window (creator.vim:15-16).

if exists('g:loaded_nerdtree_telescope_menu')
  finish
endif
let g:loaded_nerdtree_telescope_menu = 1

let s:native_key = get(g:, 'NERDTreeMenuNativeKey', 'M')

" The items shown in the open picker. Held here so a choice resolves against
" exactly the list that was displayed: AllEnabled() re-evaluates every item's
" isActiveCallback (menu_item.vim:17-25), so re-reading it to run a selection
" could return a differently indexed list.
let s:items = []

" Verbatim what NERDTree binds to `m` by default (ui_glue.vim:680-683). Copied
" rather than called because the original is script-local to ui_glue.vim.
"
" noice is stood down around it. showMenu() repaints its whole prompt on every
" keypress inside a getchar() loop, and noice's message pipeline renders each
" repaint as another notification. Scoped to this call rather than the session
" (noice/init.lua:39,55), so ordinary messages stay in noice's UI.
function! NERDTreeMenuNative(node) abort
  let l:noiced = luaeval('package.loaded["noice"] ~= nil and require("noice.config").is_running()')
  if l:noiced
    lua require('noice').disable()
  endif
  try
    let l:mc = g:NERDTreeMenuController.New(g:NERDTreeMenuItem.AllEnabled())
    call l:mc.showMenu()
  finally
    if l:noiced
      lua require('noice').enable()
    endif
  endtry
endfunction

" Called back from Lua once the picker has closed and focus is in the tree.
function! NERDTreeMenuExecute(idx) abort
  call s:items[a:idx].execute()
endfunction

function! NERDTreeMenuTelescope(node) abort
  if !luaeval('_G.NERDTreeMenuPicker ~= nil')
    call NERDTreeMenuNative(a:node)
    return
  endif

  let s:items = filter(copy(g:NERDTreeMenuItem.AllEnabled()), '!v:val.isSeparator()')

  " Only the display fields cross into Lua. The items themselves hold funcrefs,
  " which luaeval cannot convert, so selections come back by index instead.
  let l:entries = []
  for l:i in range(len(s:items))
    call add(l:entries, {
          \ 'idx': l:i,
          \ 'text': s:items[l:i].text,
          \ 'shortcut': type(s:items[l:i].shortcut) ==# v:t_string ? s:items[l:i].shortcut : '',
          \ })
  endfor

  call v:lua.NERDTreeMenuPicker(l:entries)
endfunction

lua << EOF
-- Absent telescope, _G.NERDTreeMenuPicker stays nil and NERDTreeMenuTelescope
-- falls back to the native menu.
local ok, pickers = pcall(require, 'telescope.pickers')
if ok then
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local themes = require('telescope.themes')

  -- NERDTree spells the shortcut into the label itself: "(a)dd a childnode".
  -- Pull the parens off and start with a capital, so the row reads as a plain
  -- sentence. The shortcut is not displayed, but it stays in the entry's
  -- ordinal below, so typing it still filters to that item.
  local function pretty(text)
    local label = text:gsub('%((%a)%)', '%1')
    return (label:gsub('^%l', string.upper))
  end

  function _G.NERDTreeMenuPicker(entries)
    -- Every menu callback resolves its target through GetSelected(), which
    -- reads b:NERDTree and line('.') of the CURRENT window
    -- (tree_file_node.vim:173-186). While the picker is up that window is the
    -- Telescope prompt, so the tree window has to be restored before running
    -- anything. NERDTree's own controller relies on the same ordering: it
    -- leaves its getchar() loop before calling execute()
    -- (menu_controller.vim:45,52-54).
    local tree_win = vim.api.nvim_get_current_win()

    local rows, widest = {}, 0
    for _, e in ipairs(entries) do
      local label = pretty(e.text)
      widest = math.max(widest, vim.fn.strdisplaywidth(label))
      table.insert(rows, { idx = e.idx, key = e.shortcut, label = label })
    end

    -- get_cursor hardcodes width 80 and height 9 (themes.lua:80-83), which is
    -- far wider than any label here and shows only 5 of the 11 items. Size to
    -- the content instead, clamped so an oddly long entry cannot blow it out.
    -- The +8 covers the selection caret, borders and the scrollbar; the +4
    -- covers the prompt row and the horizontal borders.
    local width = math.min(math.max(widest + 8, 40), 80)
    local height = math.min(math.max(#rows + 4, 9), math.floor(vim.o.lines * 0.8))

    pickers.new(themes.get_cursor({
      layout_config = { width = width, height = height },
    }), {
      prompt_title = 'NERDTree',
      finder = finders.new_table({
        results = rows,
        entry_maker = function(row)
          return {
            value = row,
            ordinal = row.label .. ' ' .. row.key,
            display = row.label,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry then
            return
          end
          -- Scheduled so the picker is fully torn down first: several callbacks
          -- open an input() prompt of their own (fs_menu.vim:191-227).
          vim.schedule(function()
            if vim.api.nvim_win_is_valid(tree_win) then
              vim.api.nvim_set_current_win(tree_win)
            end
            vim.fn.NERDTreeMenuExecute(entry.value.idx)
          end)
        end)
        return true
      end,
    }):find()
  end
end
EOF

" scope must match the default binding's 'Node' (ui_glue.vim:65). KeyMap.Add
" stores under key . scope (key_map.vim:161), so registering this as 'all'
" would add a second mapping beside the original rather than replace it.
function! s:RegisterKeyMaps() abort
  if !exists('*NERDTreeAddKeyMap')
    return
  endif

  call NERDTreeAddKeyMap({
        \ 'key': g:NERDTreeMapMenu,
        \ 'scope': 'Node',
        \ 'callback': 'NERDTreeMenuTelescope',
        \ 'quickhelpText': 'show menu in a Telescope picker',
        \ 'override': 1 })

  call NERDTreeAddKeyMap({
        \ 'key': s:native_key,
        \ 'scope': 'Node',
        \ 'callback': 'NERDTreeMenuNative',
        \ 'quickhelpText': 'show the built-in menu' })
endfunction

augroup nerdtree_telescope_menu
  autocmd!
  autocmd VimEnter * call s:RegisterKeyMaps()
augroup END

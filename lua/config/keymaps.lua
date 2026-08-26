-- Keymaps. Port of config/keybinds.vim, remapped onto snacks.nvim.
--
-- Requiring winbar here also loads it at startup (sets its tracking autocmds),
-- the way sourcing config/winbar.vim did. Every map keeps { silent = true } and
-- carries a desc. Leader is \ (mapleader is unset -- keep it that way).

local winbar = require("winbar")

-- Toggle the snacks explorer sidebar with Ctrl+t. Inside picker windows
-- snacks' buffer-local <c-t> (open-in-tab) wins; acceptable.
vim.keymap.set('n', '<C-t>', function()
  local p = Snacks.picker.get({ source = 'explorer' })[1]
  if p then p:close() else Snacks.explorer.open() end
end, { silent = true, desc = 'Explorer toggle' })

-- Switch to the NEXT/PREVIOUS buffer in the CURRENT WINDOW's own strip
-- (lua/winbar.lua), not the global buffer list.
vim.keymap.set('n', '<Tab>', winbar.next, { silent = true, desc = 'WinbarNext' })
vim.keymap.set('n', '<S-Tab>', winbar.prev, { silent = true, desc = 'WinbarPrev' })

-- Ctrl+q closes a tab (buffer) without closing the window: Snacks.bufdelete
-- preserves the layout, and a modified buffer prompts save/discard. The winbar
-- strips self-heal via their buflisted filter.
vim.keymap.set('n', '<C-q>', function() Snacks.bufdelete() end, { silent = true, desc = 'CloseBuffer' })

-- ---- Leader mappings (leader is \) ----
vim.keymap.set('n', '<leader>bd', function() Snacks.bufdelete() end, { silent = true, desc = 'Close buffer' })

-- layout=dropdown -- centred box, no preview pane.
vim.keymap.set('n', '<leader>pf', function() Snacks.picker.files({ layout = 'dropdown' }) end, { silent = true, desc = 'Find files' })
vim.keymap.set('n', '<leader>ps', function() Snacks.picker.grep({ layout = 'dropdown' }) end, { silent = true, desc = 'Search in files' })
vim.keymap.set('n', '<leader>pn', function() Snacks.picker.notifications({ layout = 'dropdown' }) end, { silent = true, desc = 'Messages log' })
vim.keymap.set('n', '<leader>pb', function() Snacks.picker.buffers({ layout = 'buflist' }) end, { silent = true, desc = 'Buffers' })

-- Git: lazygit in a snacks float (snacks themes it to match the colorscheme);
-- status as an ivy picker -- bottom panel with a preview, suits a status list.
vim.keymap.set('n', '<leader>gg', function() Snacks.lazygit() end, { silent = true, desc = 'Lazygit' })
vim.keymap.set('n', '<leader>gs', function() Snacks.picker.git_status({ layout = 'ivy' }) end, { silent = true, desc = 'Git status' })

-- Toggle group (\u), built on Snacks.toggle: each shows an enabled/disabled
-- icon + notification and self-registers in which-key (see toggle.which_key in
-- lua/plugins/snacks.lua). Keys mirror LazyVim's <leader>u where the concept
-- matches. \uW (whitespace/listchars) replaces the old \l. No LSP here, so no
-- diagnostics/inlay-hint toggles.
Snacks.toggle.option('spell'):map('<leader>us', { silent = true })
Snacks.toggle.option('wrap'):map('<leader>uw', { silent = true })
Snacks.toggle.line_number():map('<leader>ul', { silent = true })
Snacks.toggle.option('relativenumber'):map('<leader>uL', { silent = true })
Snacks.toggle.option('conceallevel', { off = 0, on = 2 }):map('<leader>uc', { silent = true })
Snacks.toggle.indent():map('<leader>ug', { silent = true })
Snacks.toggle.scroll():map('<leader>uS', { silent = true })
Snacks.toggle.dim():map('<leader>uD', { silent = true })
Snacks.toggle.zen():map('<leader>uz', { silent = true })
Snacks.toggle.option('list', { name = 'Whitespace' }):map('<leader>uW', { silent = true })

-- Colorscheme picker: compact list, no search bar or preview pane. The scheme applies
-- live as you scroll -- on_change fires even with the preview hidden (snacks
-- picker.lua _show_preview runs on_change before the preview-window guard).
-- Esc reverts to the theme you started on, <CR> commits. A committed pick is
-- persisted by the session (lua/session.lua); a fresh launch with no session
-- falls back to the default (github_dark_tritanopia) in lua/plugins/colorschemes.lua.
-- The active theme is marked (a left dot) and preselected on open; after a pick
-- it commits, so reopening lands on that previous choice.
vim.keymap.set('n', '<leader>h', function()
  local original, original_bg = vim.g.colors_name or 'github_dark_tritanopia', vim.o.background
  local committed = false
  Snacks.picker.colorschemes({
    -- No search bar: hide input, focus the list (single <Esc> then cancels). The
    -- full layout is inlined -- a provided layout.layout skips preset resolution,
    -- so hidden/footer apply cleanly. Footer shows the <CR>/<Esc> help.
    focus = 'list',
    layout = {
      hidden = { 'input', 'preview' },
      layout = {
        backdrop = false,
        width = 0.3, min_width = 40, max_width = 60,
        height = 0.4, min_height = 2,
        box = 'vertical',
        border = true,
        title = 'ColorScheme Manager',
        title_pos = 'center',
        footer = {
          { ' ', 'SnacksFooter' },
          { ' <Enter> ', 'SnacksFooterKey' }, { ' save ', 'SnacksFooterDesc' },
          { '     ', 'SnacksFooter' },
          { ' <Esc> ', 'SnacksFooterKey' }, { ' close ', 'SnacksFooterDesc' },
          { ' ', 'SnacksFooter' },
        },
        footer_pos = 'center',
        { win = 'input', height = 1, border = 'bottom' },
        { win = 'list', border = 'none' },
        { win = 'preview', title = '{preview}', height = 0.4, border = 'top' },
      },
    },
    -- Mark the active theme and move the cursor onto it. `current` is set once
    -- here, before any on_change scroll, so the dot stays pinned to the theme
    -- that was active when the picker opened (= last session's pick on reopen).
    finder = function(_, ctx)
      local items = require('snacks.picker.source.vim').colorschemes()
      -- Ascending by name (the source globs in runtimepath order). Sort before
      -- the set_target below so its index matches the displayed row.
      table.sort(items, function(a, b) return a.text < b.text end)
      for i, item in ipairs(items) do
        if item.text == vim.g.colors_name then
          item.current = true
          ctx.picker.list:set_target(i)
        end
      end
      return items
    end,
    format = function(item, picker)
      local ret = { { item.current and '● ' or '  ', 'DiagnosticOk' } }
      vim.list_extend(ret, require('snacks.picker.format').text(item, picker))
      return ret
    end,
    on_change = function(_, item)
      if item then pcall(vim.cmd.colorscheme, item.text) end
    end,
    confirm = function(picker, item)
      committed = true
      picker:close()
      if item then
        vim.schedule(function() pcall(vim.cmd.colorscheme, item.text) end)
      end
    end,
    on_close = function()
      if not committed then
        vim.schedule(function()
          pcall(vim.cmd.colorscheme, original)
          vim.o.background = original_bg
        end)
      end
    end,
  })
end, { silent = true, desc = 'Colorschemes' })

-- Dev layout: explorer left, file middle, claude top-right, pi bottom-right.
-- Terminals launch via :terminal so restart.lua's resume_patch term:// rewrite
-- keeps working. Splits are created before reveal because reveal targets the
-- current buffer's window set; the sidebar's editor-relative left position is
-- layout-order independent.
vim.keymap.set('n', '<leader>d', function()
  local buf = vim.api.nvim_get_current_buf()
  vim.cmd('vertical botright 120new')
  vim.cmd('terminal claude')
  vim.cmd('belowright 30new')
  vim.cmd('terminal pi')
  if not pcall(Snacks.explorer.reveal, { buf = buf }) then
    Snacks.explorer.open()   -- unnamed buffer: reveal fails, just open the sidebar
  end
  local win = vim.fn.win_findbuf(buf)[1]
  if win then vim.fn.win_gotoid(win) end   -- end focused on the file, like <C-w>t<C-w>l did
end, { silent = true, desc = 'Development mode' })

-- Toggleable snacks terminals (lua/terminals.lua): \t group, all splits
-- relative to the CURRENT window. Fixed count ids keep pairs distinct and
-- let :Restart reopen the same terminals toggleably. Claude/OMP terminals
-- open a shell and type the launch command in once the job channel is ready.
local terminals = require('terminals')
vim.keymap.set('n', '<leader>tt', terminals.bottom,          { silent = true, desc = 'Terminal split bottom' })
vim.keymap.set('n', '<leader>tv', terminals.vertical,        { silent = true, desc = 'Terminal split right' })
vim.keymap.set('n', '<leader>tc', terminals.claude_bottom,   { silent = true, desc = 'Claude split bottom' })
vim.keymap.set('n', '<leader>tx', terminals.claude_vertical, { silent = true, desc = 'Claude split right' })
vim.keymap.set('n', '<leader>tp', terminals.omp_bottom,      { silent = true, desc = 'OMP split bottom' })
vim.keymap.set('n', '<leader>to', terminals.omp_vertical,    { silent = true, desc = 'OMP split right' })

vim.keymap.set('n', '<leader>R', '<cmd>RestartRestoreSession<cr>', { silent = true, desc = 'Restart (restore everything)' })

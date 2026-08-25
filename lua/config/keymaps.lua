-- Keymaps. Port of config/keybinds.vim, remapped onto snacks.nvim.
--
-- Requiring winbar here also loads it at startup (sets its tracking autocmds),
-- the way sourcing config/winbar.vim did. Every map keeps { silent = true } and
-- carries a desc so which-key's icon rules (matched against desc:lower()) hit.
-- Leader is \ (mapleader is unset -- keep it that way).

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

-- Reveal whitespace in the current window ('listchars' set in options.lua).
vim.keymap.set('n', '<leader>l', function() vim.wo.list = not vim.wo.list end, { silent = true, desc = 'Toggle listchars' })

-- Colorscheme picker (see lua/plugins/colorschemes.lua for the theme list)
vim.keymap.set('n', '<leader>h', '<cmd>Themery<cr>', { silent = true, desc = 'Themery (colorscheme)' })

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

vim.keymap.set('n', '<leader>R', '<cmd>Restart<cr>', { silent = true, desc = 'Restart (restore everything)' })

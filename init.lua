-- Neovim config entry point (Lua, lazy.nvim). Replaces init.vim + config/*.vim.
--
-- Order mirrors the old init.vim numbered sections: settings, then the lazy
-- bootstrap (which loads every plugin and applies the colorscheme + saved
-- theme), then keymaps, then the file-change autoreload, then :Restart.

require("config.options")   -- settings + appearance + providers
require("config.lazy")      -- lazy.nvim bootstrap + all plugin specs
require("config.keymaps")   -- mappings (also loads winbar)

-- Auto-detect external file changes (autocmds + polling timer).
require("autoreload").enable()

-- Per-cwd session: save on quit + periodically, restore on launch. Replaces
-- the auto-session plugin, reusing :Restart's own save/restore machinery.
require("restart").setup()

-- :Restart -- restart nvim, restoring the whole layout. The module is required
-- on first use, preserving the old autoload deferral (autoload/restart.vim).
vim.api.nvim_create_user_command("Restart", function()
  require("restart").run()
end, {})

-- :SessionSave -- manual checkpoint of the current dir's session (non-destructive).
-- :SessionDelete -- remove the current dir's saved session.
vim.api.nvim_create_user_command("SessionSave", function()
  require("restart").save_now()
end, {})
vim.api.nvim_create_user_command("SessionDelete", function()
  require("restart").delete_session()
end, {})

-- Type it lowercase. A user command cannot be named `restart` (E183), and
-- :restart is Nvim's own built-in -- so abbreviate instead. The guard means only
-- a bare `:restart` expands; `:restart <args>` still reaches the built-in.
vim.cmd([[cnoreabbrev <expr> restart (getcmdtype() ==# ':' && getcmdline() ==# 'restart') ? 'Restart' : 'restart']])

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

-- Per-cwd session: save on quit + periodically, restore on launch.
require("session").setup()

-- Restart nvim and restore the whole layout (files, windows, explorer,
-- terminals). Renamed from :Restart; underscores aren't legal in command
-- names, so :restart_RestoreSession becomes :RestartRestoreSession.
vim.api.nvim_create_user_command("RestartRestoreSession", function()
  require("session").run()
end, {})

-- :SessionSave -- manual checkpoint of the current dir's session (non-destructive).
-- :SessionDelete -- remove the current dir's saved session.
vim.api.nvim_create_user_command("SessionSave", function()
  require("session").save_now()
end, {})
vim.api.nvim_create_user_command("SessionDelete", function()
  require("session").delete_session()
end, {})

-- Typing a bare `restart` expands to the custom command; `:restart <args>`
-- still reaches Nvim's built-in :restart.
vim.cmd([[cnoreabbrev <expr> restart (getcmdtype() ==# ':' && getcmdline() ==# 'restart') ? 'RestartRestoreSession' : 'restart']])

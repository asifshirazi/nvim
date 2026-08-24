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

-- :Restart -- restart nvim, restoring the whole layout. The module is required
-- on first use, preserving the old autoload deferral (autoload/restart.vim).
vim.api.nvim_create_user_command("Restart", function()
  require("restart").run()
end, {})

-- Type it lowercase. A user command cannot be named `restart` (E183), and
-- :restart is Nvim's own built-in -- so abbreviate instead. The guard means only
-- a bare `:restart` expands; `:restart <args>` still reaches the built-in.
vim.cmd([[cnoreabbrev <expr> restart (getcmdtype() ==# ':' && getcmdline() ==# 'restart') ? 'Restart' : 'restart']])

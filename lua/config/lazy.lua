-- lazy.nvim bootstrap and setup.
--
-- Replaces vim-plug (config/plugins.vim + autoload/plug.vim). Plugins are
-- declared one spec-file per plugin under lua/plugins/*.lua and imported here.
--
-- Load-order contract (replaces init.vim's numbered sections):
--   settings -> plugins on rtp -> `colorscheme nord` fallback -> themery applies
--   the saved theme -> everything else.
-- With lazy.nvim:
--   * All specs are eager (defaults.lazy = false). 1:1 parity, no lazy-loading.
--   * Every colorscheme plugin has priority = 1000; nord's config runs
--     vim.cmd.colorscheme("nord") (the fresh-machine fallback).
--   * themery's spec is priority = 900 so its setup() (which applies the
--     persisted theme) runs after the nord fallback and before default-priority
--     (50) plugins. snacks.nvim is also priority = 1000 (per its README, its
--     setup should run early; it only creates autocmds).

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  defaults = { lazy = false },
  install = { colorscheme = { "nord" } },
  checker = { enabled = false },
  rocks = { enabled = false },
})

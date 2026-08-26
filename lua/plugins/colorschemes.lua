-- Colorschemes. github_dark_tritanopia is the active default; the rest stay
-- installed as options for the picker.
--
-- Every colorscheme plugin is priority = 1000 so it loads before default
-- plugins, putting all schemes on the runtimepath before configs run. Only the
-- github-nvim-theme spec calls vim.cmd.colorscheme, so it wins at startup
-- regardless of config order. To change the default permanently, edit the
-- colorscheme name in that spec below.
--
-- Browse/switch at runtime with \h -> Snacks.picker.colorschemes() (live
-- preview). A committed pick is persisted by the session (lua/session.lua); a
-- fresh launch with no session falls back to this default.

return {
  -- Active default. 11 github_* schemes; the colors/*.vim files self-load via
  -- require('github-theme').load, so a bare colorscheme call is enough.
  {
    "projekt0n/github-nvim-theme",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("github_dark_tritanopia")
    end,
  },

  -- Installed as picker options only (no config -> never forced active).
  { "ellisonleao/gruvbox.nvim", priority = 1000 },
  -- `nord`; name = "nord" replaces vim-plug's { 'as': 'nord' }.
  { "nordtheme/vim", name = "nord", priority = 1000 },
  -- `vague`
  { "vague-theme/vague.nvim", priority = 1000 },
  -- modus_operandi (light) / modus_vivendi (dark)
  { "miikanissi/modus-themes.nvim", priority = 1000 },
  -- tokyonight[-night/-storm/-moon/-day]
  { "folke/tokyonight.nvim", priority = 1000 },
}

-- Colorschemes + themery switcher. Ported from config/plugins.vim (the Plug
-- lines) and config/themery.vim.
--
-- Every colorscheme plugin is priority = 1000 so it loads before default plugins.
-- nord's config runs `colorscheme nord` -- the fresh-machine fallback (init.vim
-- section 3). themery is priority = 900 so its setup() applies the persisted
-- theme AFTER the nord fallback (init.vim section 6). getcompletion sees every
-- colorscheme because lazy puts all eager plugins on rtp before running configs.

return {
  -- `nord`; name = "nord" replaces vim-plug's { 'as': 'nord' }.
  {
    "nordtheme/vim",
    name = "nord",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("nord")
    end,
  },

  -- 11 github_* schemes
  { "projekt0n/github-nvim-theme", priority = 1000 },
  -- `vague`
  { "vague-theme/vague.nvim", priority = 1000 },
  -- modus_operandi (light) / modus_vivendi (dark)
  { "miikanissi/modus-themes.nvim", priority = 1000 },
  -- tokyonight[-night/-storm/-moon/-day]
  { "folke/tokyonight.nvim", priority = 1000 },

  -- :Themery picker. priority = 900 so setup() runs after the nord fallback.
  {
    "zaldih/themery.nvim",
    priority = 900,
    config = function()
      require("themery").setup({
        livePreview = true,
        -- Every switch starts from background=dark, so no scheme can strand the
        -- setting on light. The light-first schemes still in the auto-list (shine,
        -- peachpuff, delek) therefore render in their dark variant; to rescue one,
        -- add it to the exceptions below the same way `morning` is handled.
        -- The github_light* schemes need no exception: they set &background
        -- themselves, after this hook runs.
        globalBefore = [[ vim.opt.background = "dark" ]],
        -- Discovered list, with hand-written exceptions in front. An exception is
        -- filtered out of the auto-list so it appears once, not twice.
        themes = (function()
          local exceptions = {
            { name = 'morning (light)', colorscheme = 'morning',
              before = [[ vim.opt.background = "light" ]] },
            -- modus_operandi renders LIGHT but never sets &background itself.
            { name = 'modus_operandi (light)', colorscheme = 'modus_operandi',
              before = [[ vim.opt.background = "light" ]] },
          }
          -- Bare `modus` is excluded: it caches the last variant applied, so after
          -- visiting modus_vivendi it renders DARK while claiming to be the light
          -- one. modus_operandi/modus_vivendi are deterministic and cover both modes.
          local excluded = { modus = true }
          -- Substituted IN PLACE, not prepended: an exception keeps the alphabetical
          -- slot of the scheme it overrides, so related entries (modus, modus_operandi,
          -- modus_vivendi) stay adjacent instead of being split across the list.
          local byScheme = {}
          for _, e in ipairs(exceptions) do byScheme[e.colorscheme] = e end

          local list = {}
          for _, name in ipairs(vim.fn.getcompletion('', 'color')) do
            if not excluded[name] then
              -- string shorthand; config.lua:58 normalizes it into a table
              table.insert(list, byScheme[name] or name)
            end
          end
          return list
        end)(),
      })
    end,
  },
}

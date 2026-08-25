-- folke/snacks.nvim -- explorer, pickers, notifier, terminal, and QoL modules.
-- Replaces the old file-tree/fuzzy-finder/notification/icon plugin stack.
-- Keymaps live in lua/config/keymaps.lua. No dashboard: auto-session keeps
-- owning empty startup.

return {
  {
    "folke/snacks.nvim",
    priority = 1000, -- per README: setup early (creates autocmds only)
    opts = {
      bigfile = { enabled = true },
      explorer = { enabled = true }, -- replace_netrw = true default
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      picker = {
        enabled = true,
        sources = {
          explorer = {
            hidden = true, -- show dotfiles
            watch = true,  -- auto-refresh tree on filesystem changes (fs-events)
            layout = { layout = { width = 22 } }, -- sidebar preset (search input on top)
          },
        },
      },
      quickfile = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
    },
    config = function(_, opts)
      require("snacks").setup(opts)
      -- Parity with the old NERDTree quit-if-last-window autocmd: :q of the last
      -- file window with only the explorer left quits nvim. If the explorer
      -- layout keeps a second (input) window, winnr('$')==1 is never true and
      -- this is a harmless no-op (explorer just stays open).
      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
          if vim.fn.winnr("$") == 1 and vim.bo.filetype == "snacks_picker_list" then
            vim.cmd.quit()
          end
        end,
      })

      -- Give snacks terminals (and other SnacksNormal windows) the darker
      -- NormalFloat background, so a terminal pane tones with the explorer
      -- sidebar instead of the lighter editor Normal. snacks links SnacksNormal
      -- -> NormalFloat only with default=true, and tokyonight defines it first
      -- with no bg, so re-assert the link here and on every colorscheme change
      -- (themery \h re-applies the theme, which would otherwise clobber it).
      local function tone_snacks_normal()
        vim.api.nvim_set_hl(0, "SnacksNormal", { link = "NormalFloat" })
        vim.api.nvim_set_hl(0, "SnacksNormalNC", { link = "NormalFloat" })
      end
      tone_snacks_normal()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = tone_snacks_normal })

      -- Plain :terminal windows (the \d dev-layout claude/pi panes) are not
      -- snacks windows, so the relink above never reaches them -- they use the
      -- global Normal. Map their Normal to NormalFloat on open so they tone with
      -- the explorer too. Skipped when a Normal mapping already exists, which
      -- leaves the snacks \c terminal (Normal:SnacksNormal) untouched.
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function()
          local wh = vim.wo.winhighlight
          if not wh:find("Normal:", 1, true) then
            vim.wo.winhighlight = (wh == "" and "" or wh .. ",")
              .. "Normal:NormalFloat,NormalNC:NormalFloat"
          end
        end,
      })
    end,
  },
  -- Icon provider: used by snacks picker/explorer and by lua/winbar.lua
  -- (replaces VimScript vim-devicons; get_icon_color lazily self-setups).
  { "nvim-tree/nvim-web-devicons" },
}

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
            hidden = true,                        -- parity: NERDTreeShowHidden=1
            layout = { layout = { width = 22 } }, -- parity: NERDTreeWinSize=22
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
    end,
  },
  -- Icon provider: used by snacks picker/explorer and by lua/winbar.lua
  -- (replaces VimScript vim-devicons; get_icon_color lazily self-setups).
  { "nvim-tree/nvim-web-devicons" },
}

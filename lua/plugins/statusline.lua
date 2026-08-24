-- Statusline: lualine fed by gitsigns -- the same pairing LazyVim ships
-- (nickjj's setup). gitsigns diffs each buffer against the git index: it
-- draws the hunk signs in the gutter (rendered by snacks.statuscolumn) and
-- exposes b:gitsigns_status_dict, which lualine's diff component reads for
-- the +n ~n -n counts. The branch segment is lualine's own.
--
-- The tabline stays off: the per-window buffer strip is lua/winbar.lua.

return {
  { "lewis6991/gitsigns.nvim", opts = {} },

  {
    "nvim-lualine/lualine.nvim",
    init = function()
      vim.opt.showmode = false -- lualine_a already shows the mode
    end,
    opts = {
      options = {
        theme = "auto",       -- follows themery colorscheme switches
        globalstatus = false, -- one bar per window (nickjj keeps laststatus=2)
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = { { "filename", path = 1 } }, -- relative path, not just the tail
        lualine_x = {
          {
            "diff",
            source = function()
              local s = vim.b.gitsigns_status_dict
              if s then
                return { added = s.added, modified = s.changed, removed = s.removed }
              end
            end,
          },
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
}

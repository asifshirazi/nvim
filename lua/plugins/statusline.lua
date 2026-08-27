-- Statusline: lualine fed by gitsigns. gitsigns diffs each buffer against the
-- git index: it
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
        theme = "auto",       -- follows colorscheme switches
        globalstatus = false, -- one bar per window (laststatus=2)
        -- The snacks terminal already carries a winbar label, so its bottom bar
        -- is optional. Default: visible everywhere. lua/term_statusline.lua owns
        -- the persisted show/hide preference (toggled by \ut) and seeds the
        -- initial disabled list here -- {} unless a prior \ut hid it. lualine owns
        -- per-window statuslines (rewrites wo.statusline every refresh), so
        -- disabled_filetypes is the only lever that sticks.
        disabled_filetypes = { statusline = require("term_statusline").initial_disabled() },
        -- Slant after the left sections, a rounded cap before the right ones.
        -- section_separators.left sits on the right edge of a|b|c; .right sits
        -- on the left edge of x|y|z. Written as \u{} so the source stays ASCII.
        section_separators = { left = "\u{e0b8}", right = "\u{e0b6}" },
        -- No component chevrons: '' drops the > / < between components (the
        -- pointed dividers around progress/location in the default).
        component_separators = "",
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
        lualine_z = { { "location", icon = "\u{f0263}" } }, -- nf-md-format-align-left (line rows); U+E0A1 renders as crude "LN" text
      },
    },
  },
}

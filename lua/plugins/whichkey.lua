-- which-key.nvim. Ported from config/plugins.vim and config/keybinds.vim.
--
-- The menu appears on its own once you press \ and pause for 'timeoutlen' -- no
-- prefix mapping needed. sort = { 'manual' } keeps the order listed below.

return {
  {
    "folke/which-key.nvim",
    config = function()
      -- nvim-web-devicons is installed now (snacks.nvim needs it), so the old
      -- :checkhealth "no icon provider" warning is gone. It still goes unasked
      -- here: every icon below supplies a literal glyph, and an explicit icon
      -- short-circuits rule matching (icons.lua:108) before any provider runs.
      local wk = require('which-key')
      -- icons.rules extends the built-in rules (icons.lua). Ours are matched FIRST
      -- (icons.lua:205), against desc:lower() via Lua find (icons.lua:177) -- so the
      -- patterns are lowercase, and kept narrow so they don't shadow the built-in
      -- search/window/buffer rules that already resolve.
      wk.setup {
        sort = { 'manual' },
        icons = {
          rules = {
            -- operators
            { pattern = 'yank', icon = '󰆏', color = 'yellow' },
            { pattern = 'delete', icon = '󰆴', color = 'red' },
            { pattern = 'change', icon = '󰏫', color = 'orange' },
            { pattern = 'replace', icon = '󰛔', color = 'orange' },
            { pattern = 'indent', icon = '󰉶', color = 'cyan' },
            { pattern = 'toggle case', icon = '󰬴', color = 'purple' },
            { pattern = 'visual', icon = '󰒉', color = 'purple' },
            -- motions
            { pattern = 'word', icon = '󰬗', color = 'azure' },
            { pattern = 'char', icon = '󰬊', color = 'azure' },
            { pattern = 'empty line', icon = '󰌑', color = 'grey' },
            { pattern = 'of line', icon = '󰑀', color = 'grey' },
            -- misc entries in the built-in popup
            { pattern = 'keymaps', icon = '󰌌', color = 'grey' },
            { pattern = 'help', icon = '󰋖', color = 'blue' },
            { pattern = 'run program', icon = '󰐊', color = 'green' },
            -- this config's own commands
            { pattern = 'explorer', icon = '󰙅', color = 'green' },
            { pattern = 'closebuffer', icon = '󰅖', color = 'red' },
            { pattern = 'winbarnext', icon = '󰮱', color = 'cyan' },
            { pattern = 'winbarprev', icon = '󰮲', color = 'cyan' },
          },
        },
      }
      -- Icons set explicitly, written as \u{...} escapes rather than literal glyphs
      -- so nothing can strip them in transit. An explicit icon short-circuits rule
      -- matching (icons.lua:108 -- and an EMPTY string is truthy in Lua, which is how
      -- these silently rendered blank before).
      wk.add {
        { '<leader>t', group = 'picker', icon = { icon = '\u{f0b4e}', color = 'blue' } },                        -- nf-md spyglass (U+F0B4E)
        { '<leader>tf', desc = 'Find files', icon = { icon = '\u{f021e}', color = 'blue' } },                    -- nf-md-file_find
        { '<leader>ts', desc = 'Search in files', icon = { icon = '\u{f13b8}', color = 'blue' } },               -- nf-md-text_search
        { '<leader>g', group = 'git', icon = { icon = '\u{f02a2}', color = 'orange' } },                         -- nf-md-git
        { '<leader>gg', desc = 'Lazygit', icon = { icon = '\u{f02a2}', color = 'orange' } },                     -- nf-md-git
        { '<leader>gs', desc = 'Git status', icon = { icon = '\u{f062c}', color = 'orange' } },                  -- nf-md-source_branch
        { '<leader>l', desc = 'Toggle listchars', icon = { icon = '\u{f0208}', color = 'cyan' } },               -- nf-md-eye
        { '<leader>h', desc = 'Themery (colorscheme)', icon = { icon = '\u{f03d8}', color = 'purple' } },        -- nf-md-palette
        { '<leader>d', desc = 'Development mode', icon = { icon = '\u{f0bcc}', color = 'orange' } },             -- nf-md-view_split_vertical
        { '<leader>c', desc = 'Terminal', icon = { icon = '\u{f018d}', color = 'red' } },                        -- nf-md-console
        { '<leader>R', desc = 'Restart (restore everything)', icon = { icon = '\u{f0450}', color = 'green' } },  -- nf-md-refresh
        { '<leader>b', group = 'buffer', icon = { icon = '\u{f0219}', color = 'cyan' } },                        -- nf-md-file_document
        { '<leader>bd', desc = 'Close buffer', icon = { icon = '\u{f0156}', color = 'cyan' } },                  -- nf-md-close
      }
    end,
  },
}

-- Command line & messages: blink.cmp (cmdline-only) + noice.
--
-- blink completes the COMMAND LINE ONLY. There is no LSP here and nothing to
-- complete in insert mode, so the default source list is empty and insert mode
-- gets no popup -- exactly what the old nvim-cmp setup did, now with blink's
-- own fuzzy matcher instead of four cmp plugins.

return {
  {
    "saghen/blink.cmp",
    version = "1.*", -- release tag: pulls blink's prebuilt fuzzy binary
    opts = {
      -- <CR> accepts, <Tab>/<S-Tab> unused (no insert-mode completion).
      keymap = { preset = "enter" },
      completion = {
        list = { selection = { preselect = false, auto_insert = false } },
        ghost_text = { enabled = false },
      },
      -- No insert-mode sources: nothing to complete against without an LSP.
      -- The cmdline provider below is the only one that ever runs.
      sources = {
        default = {},
        providers = {
          cmdline = {
            -- Command NAMES need 4+ chars before the menu shows (matches
            -- nickjj's tuning); once past the first word -- args and paths --
            -- it completes immediately.
            min_keyword_length = function(ctx)
              if ctx.mode == "cmdline" and string.find(ctx.line, " ") == nil then
                return 4
              end
              return 0
            end,
          },
        },
      },
      cmdline = {
        enabled = true,
        completion = {
          list = { selection = { preselect = false } },
          menu = {
            -- Only auto-show for `:`. `/` and `?` search stay on the bottom
            -- line (noice's bottom_search preset) with no popup.
            auto_show = function(_)
              return vim.fn.getcmdtype() == ":"
            end,
          },
        },
        keymap = {
          preset = "cmdline",
          ["<CR>"] = { "accept_and_enter", "fallback" },
        },
      },
    },
  },

  {
    "folke/noice.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",   -- noice dependency (required)
      -- No notify plugin needed: noice's notify view backend order is
      -- {"snacks","notify"}, so snacks.notifier (lua/plugins/snacks.lua) serves it.
    },
    config = function()
      -- noice takes the cmdline and popupmenu out of the bottom line and renders
      -- them as floats, via Neovim's vim.ui_attach API.
      require('noice').setup({
        -- Messages are noice's (its default), so plugin echomsg confirmations
        -- surface as notifications rather than on the bottom line.
        --
        -- noice's own completion popup is off: blink draws the cmdline menu, so
        -- this leaves one popup implementation rather than two competing ones.
        popupmenu = { enabled = false },
        presets = {
          bottom_search = true,       -- keep / and ? on the classic bottom line
          command_palette = true,     -- cmdline and its popup sit together, centred
        },
      })
    end,
  },
}

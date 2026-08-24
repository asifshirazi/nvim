-- Command line & messages: nvim-cmp (cmdline-only) + noice. Ported from
-- config/plugins.vim and init.vim section 4.
--
-- cmp is set up for the COMMAND LINE ONLY. The top-level setup deliberately
-- registers no sources, so insert mode gets no popup: there is no LSP here and
-- nothing to complete against.

return {
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-cmdline", -- : commands and their arguments
      "hrsh7th/cmp-path",    -- filesystem paths
      "hrsh7th/cmp-buffer",  -- words from the current buffer, for / and ?
    },
    config = function()
      local cmp = require('cmp')

      cmp.setup({
        -- nvim-cmp errors without a snippet expander even when nothing expands
        -- snippets. Neovim 0.10+ ships one, so this needs no extra plugin.
        snippet = { expand = function(args) vim.snippet.expand(args.body) end },
        sources = {},
      })

      -- Search: words from the current buffer.
      cmp.setup.cmdline({ '/', '?' }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = 'buffer' } },
      })

      -- Commands: paths first, falling back to command names and their arguments.
      -- cmp.config.sources() takes groups, and a later group is only consulted when
      -- every earlier one comes back empty.
      cmp.setup.cmdline(':', {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
          { { name = 'path' } },
          { { name = 'cmdline', option = { ignore_cmds = { 'Man', '!' } } } }
        ),
      })
    end,
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
        -- Hand regular cmdline completions to cmp instead of noice's own nui menu,
        -- so there is one popup implementation rather than two competing ones.
        popupmenu = { backend = 'cmp' },
        lsp = {
          -- No LSP here, but these also route cmp's documentation window through
          -- noice's markdown renderer. :checkhealth noice warns if any are missing.
          override = {
            ['cmp.entry.get_documentation'] = true,
            ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
            ['vim.lsp.util.stylize_markdown'] = true,
          },
        },
        presets = {
          bottom_search = true,       -- keep / and ? on the classic bottom line
          command_palette = true,     -- cmdline and its popup sit together, centred
        },
      })
    end,
  },
}

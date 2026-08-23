"==== 1. Plugins & keybindings ==============================================
" (everything below depends on their g: variables)
source ~/.config/nvim/plugins.vim
source ~/.config/nvim/keybinds.vim

" ==== 2. Basic settings =====================================================
syntax enable                " syntax highlighting for all filetypes
"set guifont=JetBrains\ Mono:h12
"set guicursor=n-vvc:block,i-ci-ve:ver25,r-cr:hor20,o:hor50
set encoding=utf-8           " use UTF-8 file encoding
set clipboard+=unnamedplus   " use system clipboard directly (register '+')
set mouse=a                  " mouse in all modes (click cursor, resize splits)
set mousescroll=ver:1,hor:0
set whichwrap+=<,>,h,l       " arrows cross line edges to next/prev line
set timeoutlen=250           " snappy key-repeat/escape, less lag
set updatetime=1000          " faster CursorHold -> checktime, so autoread doesn't wait for focus

" ---- Indentation ----
set tabstop=2                " visual width of a <Tab>
set shiftwidth=2             " spaces per auto-indent step

" ==== 3. Appearance =========================================================
" Default colorscheme. Themery (section 6) overrides this on every start once a
" theme has been picked, so this is really the fallback for a fresh machine or a
" deleted stdpath('data')/themery/state.json. It must stay ABOVE section 6.
" nord sets &background itself, so no `set background` is needed.
colorscheme nord
set number                      " show line numbers
set fillchars+=stl:\ ,stlnc:\   " pad status line so it looks continuous
" set noshowmode                " hide '-- INSERT --' (redundant with status bar)

" ==== 4. Command line & messages (nvim-cmp + noice) =========================
" Popup completion for :, / and ?, rendered by cmp instead of the built-in
" wildmenu.
"
" cmp is set up for the COMMAND LINE ONLY. The top-level setup deliberately
" registers no sources, so insert mode gets no popup: there is no LSP here and
" nothing to complete against.

" cmp-cmdline builds its whole list from a single getcompletion() call
" (cmp_cmdline/init.lua:136), and that call is prefix-and-case-sensitive
" unless 'fuzzy' is set. So `:tele` handed cmp nothing to work with, even
" though cmp's own matcher is fuzzy and prefers a strict case match rather
" than requiring one (cmp/matcher.lua:26-28,53-57). Fuzzy is not applied to
" file and directory names, so `:e ini` is unaffected either way.
set wildoptions+=fuzzy

lua << EOF
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

-- noice takes the cmdline and popupmenu out of the bottom line and renders
-- them as floats, via Neovim's vim.ui_attach API.
require('noice').setup({
  -- Messages stay NATIVE, rendered by Neovim on the message line as usual.
  -- noice only takes the cmdline and the popupmenu. ui/init.lua:55-63 enables
  -- each widget independently, so disabling this simply omits ext_messages
  -- from vim.ui_attach.
  --
  -- Why: NERDTree's `m` menu is an echo-driven prompt that redraws every line
  -- on each keypress inside a getchar() loop (menu_controller.vim:70-79).
  -- Routed through noice's message pipeline it lands in the wrong place and
  -- each redraw stacks another copy, because that pipeline is built for
  -- transient notifications, not a repainting interactive prompt.
  messages = { enabled = false },
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
EOF

" ==== 5. Statusline & tabline (Airline) =====================================
let g:airline#extensions#tabline#enabled = 1                " buffer tabs in built-in tabline
let g:airline#extensions#tabline#formatter = 'unique_tail'  " filename only (path shown only on name clashes)
let g:airline_powerline_fonts = 1                           " powerline glyphs (needs Nerd font)
" Airline enables its xkblayout (keyboard-layout) extension for any nvim, and
" its status() then calls luaeval('require"ime".current()') -- a module we
" don't have, which throws E5108 on redraw. Nothing here uses it.
let g:airline#extensions#xkblayout#enabled = 0
" Commented on purpose: setting this at all disables airline's colorscheme
" matching (plugin/airline.vim:24). Uncomment only to pin one theme.
"let g:airline_theme = 'onedark'

" ==== 6. Colorscheme switcher (themery) =====================================
" :Themery opens a picker over the list below; j/k moves (with live preview),
" <CR> applies + persists, q/<Esc> cancels. The choice is stored in
" stdpath('data')/themery/state.json -- this config is never rewritten.
"
" The only thing here that sets a colorscheme -- section 3's `colorscheme` and
" `set background` are commented out. Re-enabling either means keeping it ABOVE
" this section, or it clobbers the saved theme on every start.
"
" Airline follows along by matching g:colors_name (see section 5). The 11
" github_* schemes and nord each ship a same-named airline theme, so those pair
" exactly; the built-in schemes have none and resolve via g:airline_theme_map.
"
" The list is discovered at startup, not hand-written: themery has NO
" auto-discovery of its own (constants.lua:4 defaults themes to {}, and omitting
" it yields an EMPTY menu), so getcompletion() supplies the same set :colo
" completes. Plain strings are accepted -- config.lua:58 normalizes each into
" { name = <s>, colorscheme = <s> }.
lua << EOF
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
EOF

" ==== 7. File explorers =====================================================
" NERDTree, its devicons glyphs and the neutral-name highlights all live in
" nerdtree.vim. Sourced here rather than at the top because it applies
" highlights immediately and needs the colorscheme already set.
source ~/.config/nvim/nerdtree.vim

" ==== 8. Auto-detect external file changes ==================================
" Implementation lives in autoload/autoreload.vim (autocmds + a polling timer,
" so files reload even while you're typing in a terminal pane).
call autoreload#enable()

" ==== 9. Sessions (auto-session) ============================================
" Saves the layout on exit and restores it when nvim starts in the same cwd
" with no file arguments. Replaces the :Restart session logic below.
lua << EOF
require('auto-session').setup {
  -- NERDTree buffers do not survive a session: mksession restores the buffer
  -- but never registers it with NERDTree, so <C-t> would open a second tree.
  -- Closing the tree before saving (the plugin's own recommendation) avoids it.
  pre_save_cmds = { 'tabdo NERDTreeClose' },
  -- Don't restore a session for a bare home/root directory
  suppressed_dirs = { '~/', '~/Downloads', '/' },
  -- :Restart (autoload/restart.vim) leaves a sentinel before re-execing nvim.
  -- :restart starts with no file args, which is our auto-restore trigger, so
  -- without this BOTH sessions would load and every terminal would be spawned
  -- twice (two claude, two pi -- one pair hidden but still running).
  pre_restore_cmds = {
    function()
      local flag = vim.fn.stdpath('state') .. '/restart-skip-autosession'
      if vim.fn.filereadable(flag) == 0 then
        return true                        -- normal start: restore as usual
      end
      local stamp = tonumber(vim.fn.readfile(flag)[1] or '') or 0
      vim.fn.delete(flag)                  -- one-shot; never block a later start
      if os.time() - stamp > 60 then
        return true                        -- stale flag (crash): restore anyway
      end
      return false                         -- :Restart will restore instead
    end,
  },
}
EOF

" ==== 10. :Restart -- restart nvim, restoring the whole layout ===============
" Implementation lives in autoload/restart.vim, loaded on first use.
" Coexists with auto-session via a sentinel file: restart#run() writes it and
" the pre_restore hook in section 8 sees it and skips auto-session's restore
" for that one restart, so only this session is applied.
command! Restart call restart#run()
" Type it lowercase. A user command cannot be named `restart` (E183: user
" defined commands must start with an uppercase letter), and :restart is
" Nvim's own built-in -- so abbreviate instead. The guard means only a bare
" `:restart` expands; `:restart <args>` still reaches the built-in.
cnoreabbrev <expr> restart (getcmdtype() ==# ':' && getcmdline() ==# 'restart') ? 'Restart' : 'restart'

" ==== 11. Providers ==========================================================
let g:loaded_perl_provider = 0

"==== 1. Plugins & keybindings ==============================================
" (everything below depends on their g: variables)
source ~/.config/nvim/config/plugins.vim
source ~/.config/nvim/config/keybinds.vim

" ==== 2. Basic settings =====================================================
syntax enable                " syntax highlighting for all filetypes
"set guifont=JetBrains\ Mono:h12
" Block where the cursor sits on a character, bar where it sits between them.
set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50
set encoding=utf-8           " use UTF-8 file encoding
set clipboard+=unnamedplus   " use system clipboard directly (register '+')
set mouse=a                  " mouse in all modes (click cursor, resize splits)
set mousescroll=ver:1,hor:0
set whichwrap+=<,>,h,l       " arrows cross line edges to next/prev line
set timeoutlen=300           " snappy key-repeat/escape, less lag
set updatetime=1000          " faster CursorHold -> checktime, so autoread doesn't wait for focus

" ---- Indentation ----
set tabstop=2                " visual width of a <Tab>
set shiftwidth=2             " spaces per auto-indent step
set expandtab                " insert spaces, never a literal <Tab>

" ==== 3. Appearance =========================================================
" Default colorscheme. Themery (config/themery.vim) overrides this on every start
" once a theme has been picked, so this is really the fallback for a fresh machine
" or a deleted stdpath('data')/themery/state.json. It must stay ABOVE section 6,
" which is where that file is sourced.
" nord sets &background itself, so no `set background` is needed.
colorscheme nord
set number                      " show line numbers
let &statuscolumn = '%s%=%l    '  " 4 spaces between number and text
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
  -- Messages are noice's (its default), so NERDTree's echomsg confirmations
  -- surface as notifications rather than on the bottom line.
  --
  -- This was `enabled = false` for a while. NERDTree's `m` menu is an
  -- echo-driven prompt that redraws every line on each keypress inside a
  -- getchar() loop (menu_controller.vim:70-79); through noice's message
  -- pipeline it landed in the wrong place and stacked a fresh copy per
  -- keystroke, that pipeline being built for transient notifications rather
  -- than a repainting interactive prompt. `m` is a Telescope picker now and
  -- never enters that loop. The original menu is still on `M`, so
  -- NERDTreeMenuNative() in config/telescope.vim stands noice down for the
  -- length of the loop instead of the whole session.
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

" ==== 5. Statusline & winbar ================================================
" Airline's options live in config/airline.vim. Its tabline extension is off:
" the buffer list is drawn per window instead, by config/winbar.vim.
source ~/.config/nvim/config/airline.vim
source ~/.config/nvim/config/winbar.vim

" ==== 6. Colorscheme switcher (themery) =====================================
" The picker on \h and the list it offers live in config/themery.vim. Sourced
" here rather than at the top because it applies the saved theme immediately
" and so must run after section 3's `colorscheme`.
source ~/.config/nvim/config/themery.vim

" ==== 7. File explorers =====================================================
" NERDTree, its devicons glyphs and the neutral-name highlights all live in
" nerdtree.vim. Sourced here rather than at the top because it applies
" highlights immediately and needs the colorscheme already set.
source ~/.config/nvim/config/nerdtree.vim

" NERDTree's `m` menu as a Telescope picker, with the original menu on `M`.
" Sourced separately because it registers its key maps from a VimEnter autocmd
" rather than immediately, for the reasons in that file's header.
source ~/.config/nvim/config/telescope.vim

" ==== 8. Auto-detect external file changes ==================================
" Implementation lives in config/autoreload.vim (autocmds + a polling timer,
" so files reload even while you're typing in a terminal pane). Sourced rather
" than autoloaded: it is entered immediately, so laziness bought nothing.
source ~/.config/nvim/config/autoreload.vim
call AutoreloadEnable()

" ==== 9. Sessions (auto-session) ============================================
" Saves the layout on exit and restores it when nvim starts in the same cwd
" with no file arguments. Replaces the :Restart session logic below.
lua << EOF
require('auto-session').setup {
  -- NERDTree buffers do not survive a session: mksession restores the buffer
  -- but never registers it with NERDTree, so <C-t> would open a second tree.
  -- Closing the tree before saving (the plugin's own recommendation) avoids it.
  pre_save_cmds = { 'tabdo NERDTreeClose' },
  -- mksession cannot save the per-window buffer strips (config/winbar.vim):
  -- 'sessionoptions' has no word for window-local variables. These lines go to
  -- the session's companion x.vim, which Vim sources once the layout is back
  -- (:h :mksession, step 10). Returning an empty list deletes any stale file.
  save_extra_cmds = { function() return vim.fn.WinbarSessionLines() end },
  -- After each save, rewrite resumable-CLI terminal commands to add --continue,
  -- the same fix-up :Restart applies (autoload/restart.vim): without it a plain
  -- quit and reopen relaunches claude/pi/omp fresh instead of resuming. mks!
  -- above has just set v:this_session to the file it wrote.
  post_save_cmds = {
    function() vim.fn['restart#resume_patch'](vim.v.this_session) end,
  },
  -- Don't restore a session for a bare home/root directory
  suppressed_dirs = { '~/', '~/Downloads', '/' },
  -- :Restart (autoload/restart.vim) leaves a sentinel before re-execing nvim.
  -- :restart starts with no file args, which is our auto-restore trigger, so
  -- without this BOTH sessions would load and every terminal would be spawned
  -- twice (two each of claude, pi and omp -- one set hidden but still running).
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

" ==== 12. Cursor smear (smear-cursor.nvim) ==================================
lua << EOF
require('smear_cursor').setup({
  smear_between_buffers = true,
  smear_insert_mode = true,
  stiffness = 0.8,
  trailing_stiffness = 0.6,
  damping = 0.95,
  matrix_pixel_threshold = 0.5,
  stiffness_insert_mode = 0.7,
  trailing_stiffness_insert_mode = 0.7,
  damping_insert_mode = 0.95,
  distance_stop_animating = 0.5,
  time_interval = 7,
})
EOF

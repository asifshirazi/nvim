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

" ==== 4. Command-line completion (wilder) ===================================
" Fuzzy autocomplete for :, / and ?. Replaces the built-in wildmenu, which is
" why the `set wildmenu`/`wildoptions` lines in section 3 stay commented out.
call wilder#setup({
      \ 'modes': [':', '/', '?'],
      \ 'next_key': '<Tab>',
      \ 'previous_key': '<S-Tab>',
      \ 'accept_key': '<Down>',
      \ 'reject_key': '<Up>',
      \ })

" fzy matching via fzy-lua-native -- no Python remote plugin required
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline({
      \       'fuzzy': 1,
      \       'fuzzy_filter': wilder#lua_fzy_filter(),
      \     }),
      \     wilder#vim_search_pipeline(),
      \   ),
      \ ])

" glyph-palette defines g:glyph_palette#palette in autoload/glyph_palette.vim,
" which Vim only loads on the first glyph_palette#* call. wilder reads that
" variable directly, so force the autoload now -- otherwise it is undefined at
" popup time and every icon falls back to the uncoloured default.
runtime autoload/glyph_palette.vim

" Bordered popup with file glyphs (vim-devicons) and a scrollbar
call wilder#set_option('renderer', wilder#popupmenu_renderer(wilder#popupmenu_border_theme({
      \ 'border': 'rounded',
      \ 'highlighter': wilder#basic_highlighter(),
      \ 'left': [' ', wilder#popupmenu_devicons()],
      \ 'right': [' ', wilder#popupmenu_scrollbar()],
      \ })))

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
" ---- NERDTree (toggled with <C-t>, see keybinds.vim) ----
let g:NERDTreeWinPos = 'left'            " sidebar side: 'left' or 'right'
let g:NERDTreeWinSize = 22               " sidebar width in columns
let g:NERDTreeShowHidden = 1             " show dotfiles by default (toggle with I)
let g:NERDTreeMinimalUI = 1              " hide the '? for help' header
let g:NERDTreeShowLineNumbers = 0        " no line numbers in the tree
let g:NERDTreeAutoDeleteBuffer = 1       " delete the buffer of a file removed in the tree
let g:NERDTreeQuitOnOpen = 0             " set to 1 to auto-close the tree after opening a file
" Octicon chevrons, straight from the Nerd Font -- no icon plugin involved.
" DOUBLE quotes are required: in single quotes Vim takes \u literally and you
" get the six characters \uF460 on screen. Single character each
" (NERDTree.txt:1281).
let g:NERDTreeDirArrowExpandable = ""   " closed directory (nf-oct-chevron_right)
let g:NERDTreeDirArrowCollapsible = ""  " open directory   (nf-oct-chevron_down)
let g:NERDTreeLimitedSyntax = 1          " colour only common extensions -- keeps large trees fast
"let g:NERDTreeChDirMode = 2             " uncomment to :cd into the tree root as you browse

" ---- NERDTree icons (vim-devicons) ----
" The icon is rendered as a NERDTree flag: '[ icon ]'. The brackets are concealed
" (vim-devicons conceals them by default); these two control the
" padding *inside* them -- set either to '' to tighten the spacing.
let g:WebDevIconsNerdTreeBeforeGlyphPadding = ''  " gap between arrow and icon
let g:WebDevIconsNerdTreeAfterGlyphPadding = ' '   " gap between icon and filename
let g:WebDevIconsUnicodeDecorateFolderNodes = 1  " uncomment for icons on directories too
let g:DevIconsEnableFoldersOpenClose = 1         " ...with distinct open/closed folder glyphs
let g:NERDTreeHighlightFolders = 1

" NERDTree links its own name groups to Directory/Identifier with `hi def link`
" (syntax/nerdtree.vim:84,66). `def` means default, so an explicit link wins.
" Applied twice on purpose: once now, because section 3's `colorscheme` has
" already run and the autocmd below would never fire for it; and again on every
" ColorScheme, because switching theme via <leader>h wipes explicit highlights.
" The arrows are NOT affected -- they link to Directory, not to NERDTreeDir.
function! s:NeutralTreeNames() abort
  hi link NERDTreeDir Normal
  hi link NERDTreeDirSlash Normal
endfunction
call s:NeutralTreeNames()
augroup nerdtree_neutral_names
  autocmd!
  autocmd ColorScheme * call s:NeutralTreeNames()
augroup END

" Don't let devicons force its default green/white symbol colours
let g:WebDevIconsDisableDefaultFolderSymbolColorFromNERDTreeDir = 0
let g:WebDevIconsDisableDefaultFileSymbolColorFromNERDTreeFile = 0

" Close Vim if NERDTree is the only window left (a regular :NERDTree is a
" 'window'-type tree; 'tab'-type is the pinned-in-tab variant)
autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isWinTree() | quit | endif

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

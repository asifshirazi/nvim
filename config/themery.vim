" themery -- the colorscheme switcher behind \h (see config/keybinds.vim).
"
" Sourced from init.vim section 6, and the position matters: it must come after
" section 3's `colorscheme`, which it overrides.

" :Themery opens a picker over the list below; j/k moves (with live preview),
" <CR> applies + persists, q/<Esc> cancels. The choice is stored in
" stdpath('data')/themery/state.json -- this config is never rewritten.
"
" The last word on which colorscheme is active. init.vim section 3 sets
" `colorscheme nord` as the fallback for a fresh machine or a deleted state
" file, and this overrides it on every start once a theme has been picked.
" That line must stay ABOVE the source of this file, or it clobbers the saved
" theme each time.
"
" Airline follows along by matching g:colors_name (see config/airline.vim).
" The 11
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

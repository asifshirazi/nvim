" vim-airline -- the statusline.
"
" Sourced from init.vim section 5. Position is not load-bearing: these are all
" g: variables, read when airline's own plugin file is sourced, which happens
" after init.vim finishes either way.

" Off: the buffer list is drawn per window by config/winbar.vim instead, and
" airline's version is global, so both at once shows the same names twice and
" costs a screen line to do it. The formatter went with it, having nothing left
" to format.
let g:airline#extensions#tabline#enabled = 0
let g:airline_powerline_fonts = 1                           " powerline glyphs (needs Nerd font)
" Airline enables its xkblayout (keyboard-layout) extension for any nvim, and
" its status() then calls luaeval('require"ime".current()') -- a module we
" don't have, which throws E5108 on redraw. Nothing here uses it.
let g:airline#extensions#xkblayout#enabled = 0
" Commented on purpose: setting this at all disables airline's colorscheme
" matching (plugin/airline.vim:24). Uncomment only to pin one theme.
"let g:airline_theme = 'onedark'
